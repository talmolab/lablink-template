# Automate Example Configuration Testing in CI

**Status:** Draft
**Created:** 2025-12-08
**Author:** Elizabeth

## Overview

Automate deployment testing of all 10 example configurations in the ci-test environment to catch configuration errors, Terraform issues, and integration problems before users encounter them.

## Problem

### Current State: Manual Testing Only

Currently, the template provides 10 example configurations with different DNS/SSL setups:
- `ip-only.example.yaml` - No DNS, no SSL
- `cloudflare.example.yaml` - CloudFlare DNS + SSL
- `letsencrypt.example.yaml` - Route53 + Let's Encrypt SSL
- `acm.example.yaml` - Route53 + AWS ACM SSL
- `dev.example.yaml`, `test.example.yaml`, `prod.example.yaml` - Environment-specific
- `ci-test.example.yaml` - CI testing environment
- `example.config.yaml` - Complete reference config
- `starter.example.yaml` - Minimal quick-start

**Testing gap:** Only syntax validation is automated via `lablink-validate-config`. Actual deployment testing requires:
1. Manual copy of example to `config.yaml`
2. Manual workflow dispatch to deploy infrastructure
3. Manual verification of allocator service health
4. Manual VM provisioning test via allocator
5. Manual cleanup/destroy

**Problems this creates:**
- **Breaking changes go undetected**: Schema changes, Terraform updates, or AWS service changes can break example configs
- **Manual testing is incomplete**: With 10 configs, full manual testing is time-consuming and skipped
- **Users discover issues in production**: First deployment often fails with cryptic errors
- **No regression testing**: Changes to infrastructure code may break previously working configs
- **CI testing is ad-hoc**: Team members manually test configs in ci-test, risking Let's Encrypt rate limits

### Distinction: Validation vs Deployment Testing

**Config validation** (currently automated):
- Checks YAML syntax and schema compliance
- Validates required fields are present
- Catches configuration typos and format errors
- **Fast** (~10 seconds per config)
- **No cost** (runs in Docker)

**Deployment testing** (currently manual):
- Validates Terraform can parse config and plan infrastructure
- Tests actual AWS resource provisioning (EC2, security groups, EIPs, DNS, SSL)
- Verifies allocator service starts and responds
- Tests VM provisioning via allocator API
- **Slow** (~10-15 minutes per full deploy+destroy cycle)
- **Has cost** (AWS resources, even if short-lived)
- **Subject to rate limits** (Let's Encrypt: 5 certs/domain/week)

**This proposal focuses on automating deployment testing**, not just validation.

### Cost and Rate Limit Constraints

**Cost considerations:**
- **EC2 instances**: g4dn.xlarge ~$0.526/hour × 10 configs × 15 min = ~$13.15 per full test run
- **Elastic IPs**: $0.005/hour while provisioned
- **Data transfer**: Minimal for testing
- **Total estimated cost**: $15-20 per complete test run if all configs tested sequentially

**Rate limit constraints:**
- **Let's Encrypt**: 5 certificates per exact domain per 7 days
- **Impact**: `letsencrypt.example.yaml` cannot be tested more than 5 times per week using the same domain
- **Mitigation**: Use Let's Encrypt staging environment for CI testing (untrusted certs, no rate limits)

**Testing strategy needed:**
- Not every config needs full deployment testing on every PR
- Selective testing based on what changed
- Scheduled comprehensive testing (e.g., weekly)
- Cost-optimized testing for frequently-run checks

## Solution

### Multi-Level Testing Strategy

Implement a **phased testing approach** with progressively deeper validation:

#### Level 1: Syntax Validation (existing, fast, free)
**When:** Every PR affecting config files
**What:** Schema validation via `lablink-validate-config`
**Duration:** ~10 seconds per config
**Cost:** $0

#### Level 2: Terraform Plan Validation (new, fast, low-cost)
**When:** PRs affecting infrastructure code or config examples
**What:**
- Copy each example to `config.yaml`
- Run `terraform init` with ci-test backend
- Run `terraform plan` to validate Terraform can parse config
- No actual resource creation

**Benefits:**
- Catches Terraform syntax errors
- Validates variable interpolation
- Checks provider compatibility
- No AWS resource costs (plan only)

**Duration:** ~2-3 minutes per config
**Cost:** Minimal (only state storage access)

#### Level 3: Smoke Test Deployment (new, selective)
**When:**
- PRs affecting infrastructure code (terraform/*.tf)
- Manual trigger for pre-merge validation
- Scheduled weekly comprehensive test

**What:**
- Deploy infrastructure with example config to ci-test environment
- Verify allocator service responds (HTTP 200)
- Run basic health checks
- Destroy infrastructure immediately

**Configs to test:**
- `ip-only.example.yaml` - Fastest, no DNS/SSL complexity, good baseline
- `letsencrypt.example.yaml` - Most complex, uses staging environment to avoid rate limits
- Optionally: `cloudflare.example.yaml` if CloudFlare credentials available

**Duration:** ~10-15 minutes per config
**Cost:** ~$2-3 per config tested

#### Level 4: End-to-End VM Provisioning (future work, out of scope)
**When:** Major releases, manual comprehensive validation
**What:**
- Full deployment test
- Provision client VM via allocator API
- Verify VM boots and software loads
- Test Chrome Remote Desktop connectivity
- Destroy VM and infrastructure

**Duration:** ~20-30 minutes
**Cost:** ~$5-10 per test

**Out of scope for this proposal** - requires allocator API testing framework.

### Proposed CI Workflow

Create new workflow: `.github/workflows/test-example-configs.yml`

**Triggers:**
- Pull requests affecting:
  - `lablink-infrastructure/config/*.example.yaml`
  - `lablink-infrastructure/*.tf` (Terraform infrastructure)
  - `.github/workflows/test-example-configs.yml` (the workflow itself)
- Manual workflow dispatch (with config selection)
- Scheduled: Weekly full test run (Sunday 2 AM UTC)

**Workflow structure:**

```yaml
jobs:
  terraform-plan-validation:
    name: Terraform Plan - ${{ matrix.config }}
    runs-on: ubuntu-latest
    strategy:
      matrix:
        config:
          - ip-only.example.yaml
          - letsencrypt.example.yaml
          - cloudflare.example.yaml
          - acm.example.yaml
          - starter.example.yaml
    steps:
      - Checkout code
      - Configure AWS credentials (existing OIDC)
      - Setup Terraform
      - Copy ${{ matrix.config }} to config.yaml
      - Inject password placeholders (use dummy values for plan)
      - terraform init with ci-test backend
      - terraform plan -var="resource_suffix=ci-test-plan-check"
      - Report plan success/failure

  smoke-test-deployment:
    name: Deploy & Test - ${{ matrix.config }}
    runs-on: ubuntu-latest
    needs: terraform-plan-validation
    if: |
      github.event_name == 'schedule' ||
      github.event_name == 'workflow_dispatch' ||
      contains(github.event.pull_request.labels.*.name, 'test-deploy')
    strategy:
      matrix:
        config:
          - ip-only.example.yaml  # Always test - fastest, baseline
          - letsencrypt.example.yaml  # Complex case, use staging
    steps:
      - Checkout code
      - Configure AWS credentials
      - Setup Terraform
      - Copy ${{ matrix.config }} to config.yaml
      - Modify Let's Encrypt configs to use staging environment
      - Inject password secrets (use real GitHub secrets)
      - terraform init with ci-test backend
      - terraform apply with unique resource suffix (ci-test-${{ github.run_id }}-${{ strategy.job-index }})
      - Wait for allocator service health check (HTTP 200)
      - Verify DNS resolution (if DNS enabled)
      - Verify SSL certificate (if SSL enabled)
      - terraform destroy -auto-approve
      - Report test results
```

**Key implementation details:**

1. **Unique resource suffixes**: Use `ci-test-${{ github.run_id }}-${{ strategy.job-index }}` to allow parallel testing without resource conflicts

2. **Let's Encrypt staging environment**:
   - Modify `letsencrypt.example.yaml` config during test to use staging
   - Set environment variable for Caddy: `ACME_SERVER=https://acme-staging-v02.api.letsencrypt.org/directory`
   - Staging has no rate limits, issues untrusted certs (perfect for CI)

3. **Reuse existing secrets**:
   - `AWS_ROLE_ARN` - Already configured for OIDC
   - `AWS_REGION` - Already configured
   - `ADMIN_PASSWORD` - Already exists
   - `DB_PASSWORD` - Already exists
   - No new secrets needed

4. **Reuse existing backend**:
   - Use `backend-ci-test.hcl` with unique state keys
   - State key pattern: `ci-test-${{ github.run_id }}-${{ strategy.job-index }}/terraform.tfstate`
   - Automatic cleanup on destroy

5. **Cost optimization**:
   - Plan validation runs on every PR (cheap, fast)
   - Smoke deployments only on:
     - Schedule (weekly)
     - Manual trigger
     - PRs with `test-deploy` label
   - Destroy immediately after health checks pass

## Scope

### In Scope

**New CI Workflow:**
- `.github/workflows/test-example-configs.yml` - Multi-level testing workflow
  - Terraform plan validation for all configs
  - Selective smoke test deployment
  - Automated cleanup/destroy

**Documentation Updates:**
- Update `README.md` - Mention automated config testing in CI
- Update `docs/TESTING_BEST_PRACTICES.md` - Explain CI testing strategy
- Add comments to example configs explaining CI testing coverage

**Configuration Changes:**
- Modify test workflow to use Let's Encrypt staging for `letsencrypt.example.yaml`
- No changes to actual example configs (keep production-ready)

### Out of Scope

**Not included in this change:**
- End-to-end VM provisioning testing (Level 4) - requires allocator API test framework
- Testing with actual CloudFlare credentials - requires CloudFlare account and secrets
- Testing ACM configs - requires pre-provisioned ACM certificates
- Automated rollback on failed tests - manual intervention preferred
- Cost reporting/tracking - can be added later
- Performance benchmarking - different concern

**Deferred to future work:**
- Parallel deployment of multiple configs (resource quotas may be issue)
- Testing client VM provisioning via allocator API
- Testing Chrome Remote Desktop connectivity
- Automated Let's Encrypt rate limit monitoring

### Breaking Changes

None. This adds CI automation without changing any existing configurations or deployment workflows.

### Dependencies

**Existing Infrastructure (reused):**
- ci-test environment with backend config ([backend-ci-test.hcl](../../../lablink-infrastructure/backend-ci-test.hcl))
- GitHub secrets: AWS_ROLE_ARN, AWS_REGION, ADMIN_PASSWORD, DB_PASSWORD
- Existing deployment workflow logic ([terraform-deploy.yml](../../../.github/workflows/terraform-deploy.yml))

**External:**
- Let's Encrypt staging environment (for rate-limit-free testing)
- AWS resources availability in configured region
- Terraform 1.6+ compatibility

**No new dependencies or secrets required.**

## Migration Path

No migration needed. This is purely additive CI automation.

**Impact:**
- **Template users**: No impact, example configs unchanged
- **Contributors**: PRs get automatic terraform plan validation
- **Maintainers**: Can trigger comprehensive deployment tests on-demand

**Rollout plan:**
1. Create workflow with terraform plan validation only (low risk)
2. Test manually with workflow_dispatch
3. Enable scheduled weekly smoke tests
4. Monitor costs and adjust strategy as needed

## Alternatives Considered

### Alternative 1: Test all 10 configs on every PR

Test every example config with full deployment on every PR.

**Rejected because:**
- **Cost**: $15-20 per PR is prohibitively expensive
- **Time**: 150+ minutes per PR (10 configs × 15 min) too slow
- **Rate limits**: Would hit Let's Encrypt limits quickly even with staging
- **Unnecessary**: Most PRs don't affect all config types

### Alternative 2: Create separate test configs with dummy values

Create `*.test.yaml` variants of each example specifically for CI testing.

**Rejected because:**
- **Maintenance burden**: 10 additional configs to keep in sync
- **Divergence risk**: Test configs may drift from actual examples
- **User confusion**: Unclear which configs are "real"
- **Not representative**: Testing different configs than users will actually use

### Alternative 3: Use Terraform Cloud for plan automation

Use Terraform Cloud's plan automation instead of GitHub Actions.

**Rejected because:**
- **New dependency**: Requires Terraform Cloud account and integration
- **Cost**: Terraform Cloud has costs for team features
- **Complexity**: Another service to configure and maintain
- **GitHub Actions sufficient**: Existing OIDC setup works well

### Alternative 4: Only validate syntax, skip deployment testing

Keep only Level 1 (syntax validation), skip all deployment testing.

**Rejected because:**
- **Insufficient**: Syntax validation doesn't catch Terraform errors, AWS API changes, or integration issues
- **Misses real-world failures**: Many config problems only appear during actual deployment
- **User pain**: Users discover broken configs during their first deployment
- **No regression protection**: Infrastructure changes can break working configs undetected

### Alternative 5: Manual testing with documented checklist

Keep testing manual, but create comprehensive checklist for maintainers.

**Rejected because:**
- **Not scalable**: Manual testing of 10 configs is 2+ hours of work
- **Error-prone**: Humans skip steps or miss issues
- **Not repeatable**: Different people test differently
- **No PR validation**: Testing happens after merge, not before

## Success Criteria

- [ ] Terraform plan validation runs on every PR affecting infrastructure or configs
- [ ] All 10 example configs successfully pass terraform plan validation
- [ ] Smoke test deployment successfully deploys and destroys infrastructure for ip-only and letsencrypt configs
- [ ] Let's Encrypt staging environment correctly used for letsencrypt config testing (no production rate limit usage)
- [ ] Tests complete in reasonable time (<30 minutes for full run)
- [ ] Tests cost <$5 per full run (weekly scheduled test)
- [ ] Failed tests provide clear error messages indicating which config and what failed
- [ ] Workflow can be manually triggered for on-demand testing
- [ ] Documentation explains CI testing strategy and how to interpret results
- [ ] No new GitHub secrets required (reuses existing AWS_ROLE_ARN, etc.)

## Open Questions

None. Implementation details are well-defined based on existing ci-test infrastructure.

## References

- [Existing deployment workflow](../../../.github/workflows/terraform-deploy.yml) - Reuse deployment logic
- [ci-test backend config](../../../lablink-infrastructure/backend-ci-test.hcl) - Existing testing backend
- [Let's Encrypt Staging Environment](https://letsencrypt.org/docs/staging-environment/) - Rate-limit-free testing
- [GitHub Actions: Terraform](https://github.com/hashicorp/setup-terraform) - Terraform setup action
- [Testing best practices doc](../document-rate-limits-clean-docs/specs/documentation/spec.md) - Related testing guidance