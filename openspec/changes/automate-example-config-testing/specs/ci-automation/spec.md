# CI Automation Capability

**Domain:** Infrastructure Testing
**Status:** Draft

## Overview

Automated testing of example configurations in CI/CD pipelines, providing multi-level validation from syntax checking to full deployment testing.

## ADDED Requirements

### Requirement: Terraform Plan Validation for Example Configs

The CI pipeline SHALL validate that all example configurations can be successfully processed by Terraform, catching configuration errors before they reach users.

**Rationale:** Syntax validation alone is insufficient. Many configuration errors only surface when Terraform attempts to parse the config and plan infrastructure changes. Terraform plan validation catches: variable interpolation errors, provider compatibility issues, resource dependency problems, and invalid Terraform expressions.

#### Scenario: PR with infrastructure changes triggers plan validation

**Given** a pull request modifies Terraform infrastructure files (*.tf)
**When** the CI workflow runs
**Then** the system MUST:
- Copy each example config to config.yaml
- Run `terraform init` with ci-test backend configuration
- Run `terraform plan` with ci-test resource suffix
- Report success/failure for each example config
- Fail the CI check if any config fails terraform plan

#### Scenario: PR with config example changes triggers plan validation

**Given** a pull request modifies any *.example.yaml file
**When** the CI workflow runs
**Then** the system MUST:
- Validate the modified example configs with terraform plan
- Inject placeholder values for password secrets during plan
- Use ci-test backend for state management
- Report detailed error messages if plan fails

#### Scenario: Terraform plan succeeds for valid configuration

**Given** an example config with valid structure
**When** terraform plan validation runs
**Then** the system MUST:
- Successfully initialize Terraform with ci-test backend
- Successfully generate an execution plan
- Report plan success in CI check
- Complete within 3 minutes per config

#### Scenario: Terraform plan fails for invalid configuration

**Given** an example config with invalid Terraform references
**When** terraform plan validation runs
**Then** the system MUST:
- Capture the terraform plan error output
- Report the specific config file that failed
- Include relevant error messages in CI output
- Fail the CI check to block merge

### Requirement: Selective Smoke Test Deployment

The CI pipeline SHALL support selective deployment testing of example configs to ci-test environment, validating actual AWS resource provisioning without incurring excessive costs or hitting rate limits.

**Rationale:** Terraform plan validation catches many errors but cannot detect AWS API changes, region-specific issues, or runtime integration problems. Smoke test deployment actually provisions resources and verifies the allocator service starts, but testing all 10 configs on every PR is too expensive ($15-20) and time-consuming (150+ minutes). Selective testing balances coverage and cost.

#### Scenario: Scheduled weekly comprehensive deployment test

**Given** it is Sunday at 2 AM UTC (weekly schedule)
**When** the scheduled workflow runs
**Then** the system MUST:
- Deploy infrastructure using ip-only.example.yaml
- Deploy infrastructure using letsencrypt.example.yaml (with staging environment)
- Use unique resource suffix: ci-test-{run-id}-{job-index}
- Verify allocator service responds HTTP 200
- Destroy infrastructure after successful health check
- Report test results for both configs

#### Scenario: Manual workflow dispatch for pre-merge validation

**Given** a maintainer wants to test configs before merging
**When** they trigger the workflow via workflow_dispatch
**Then** the system MUST:
- Allow selection of which configs to test
- Deploy selected configs to ci-test environment
- Run health checks on deployed allocator
- Destroy infrastructure after testing
- Provide detailed test results

#### Scenario: PR with test-deploy label triggers smoke tests

**Given** a pull request has the "test-deploy" label
**When** the CI workflow runs
**Then** the system MUST:
- Run terraform plan validation (as usual)
- Additionally run smoke test deployment for ip-only and letsencrypt configs
- Use unique resource suffixes to avoid conflicts
- Destroy infrastructure automatically after tests
- Report deployment test results in PR checks

#### Scenario: Smoke test deployment succeeds

**Given** a valid example config for deployment testing
**When** smoke test runs
**Then** the system MUST:
- Successfully run terraform apply with ci-test backend
- Wait up to 60 seconds for allocator container to start
- Verify allocator HTTP endpoint returns 200 status
- Successfully run terraform destroy to clean up
- Report deployment success in CI output
- Complete within 15 minutes per config

#### Scenario: Smoke test deployment fails during apply

**Given** a config that fails during terraform apply
**When** smoke test runs
**Then** the system MUST:
- Capture terraform apply error output
- Attempt terraform destroy to clean up partial resources
- Report specific failure reason in CI output
- Fail the CI check
- Not leave orphaned AWS resources

#### Scenario: Let's Encrypt config uses staging environment in CI

**Given** letsencrypt.example.yaml being tested in CI
**When** smoke test deployment runs
**Then** the system MUST:
- Modify config to use Let's Encrypt staging environment
- Set Caddy ACME server to staging URL: https://acme-staging-v02.api.letsencrypt.org/directory
- NOT use production Let's Encrypt (to avoid rate limits)
- Verify SSL certificate obtained (even if untrusted)
- Log that staging environment was used

### Requirement: Unique Resource Naming for Parallel Testing

The CI testing infrastructure SHALL use unique resource suffixes to enable parallel or sequential testing without resource name conflicts.

**Rationale:** Multiple test runs (different PRs, scheduled runs, manual triggers) may execute concurrently. AWS resources have unique naming requirements within regions. Without unique suffixes, concurrent tests would conflict and fail. Using GitHub run IDs ensures uniqueness and traceability.

#### Scenario: Concurrent PR tests use unique resource names

**Given** two pull requests trigger CI workflows simultaneously
**When** both workflows deploy to ci-test
**Then** the system MUST:
- Use different resource suffixes: ci-test-{run-id}-{job-index}
- Create separate Terraform state files per test run
- Avoid resource name conflicts (EC2 instances, security groups, EIPs)
- Allow both tests to complete independently

#### Scenario: Resource suffix includes GitHub run ID

**Given** a CI workflow running smoke tests
**When** terraform apply is executed
**Then** the system MUST:
- Pass variable: resource_suffix=ci-test-{github.run_id}-{strategy.job-index}
- Use this suffix for all AWS resource names
- Store state in unique key: ci-test-{run-id}-{job-index}/terraform.tfstate
- Enable identification of resources by CI run

#### Scenario: Cleanup removes only test-specific resources

**Given** a smoke test has completed
**When** terraform destroy runs
**Then** the system MUST:
- Destroy only resources with the specific test's suffix
- Not affect other concurrent tests' resources
- Not affect test/prod environment resources
- Leave no orphaned resources in AWS

### Requirement: Cost-Optimized Testing Strategy

The CI testing infrastructure SHALL implement cost controls to prevent excessive AWS spending while maintaining adequate test coverage.

**Rationale:** Full deployment testing of all 10 configs costs $15-20 per run. Testing on every PR would be prohibitively expensive (could be 100+ PRs per month = $1500-2000). Selective testing provides good coverage at manageable cost (~$20/month for weekly tests + occasional manual runs).

#### Scenario: Terraform plan validation runs on every PR (low cost)

**Given** any pull request affecting infrastructure or configs
**When** CI workflow runs
**Then** the system MUST:
- Run terraform plan validation (no AWS resources created)
- Cost only state storage access (~$0.01)
- NOT create EC2 instances or other billable resources
- Complete quickly (<20 minutes total for all configs)

#### Scenario: Smoke test deployment only runs when needed (high cost)

**Given** a pull request without "test-deploy" label
**When** CI workflow runs
**Then** the system MUST:
- Run terraform plan validation (always)
- SKIP smoke test deployment (expensive)
- Save ~$5-10 in AWS costs
- Still provide good validation coverage

#### Scenario: Weekly scheduled test provides comprehensive coverage

**Given** weekly scheduled test runs (Sunday 2 AM UTC)
**When** the workflow executes
**Then** the system MUST:
- Test at least 2 representative configs (ip-only, letsencrypt)
- Cost approximately $4-6 per run
- Provide regression testing for infrastructure changes
- Run during low-usage time (weekend night)

### Requirement: Reuse Existing CI Infrastructure

The CI testing workflow SHALL leverage existing ci-test environment, backend configuration, and GitHub secrets without requiring new infrastructure or credentials.

**Rationale:** The ci-test environment already exists with backend-ci-test.hcl and AWS OIDC credentials configured. Creating new infrastructure would duplicate effort, increase maintenance burden, and require additional secret management. Reusing existing infrastructure is simpler, safer, and more maintainable.

#### Scenario: CI workflow uses existing AWS OIDC credentials

**Given** the test-example-configs workflow needs AWS access
**When** the workflow runs
**Then** the system MUST:
- Use existing AWS_ROLE_ARN secret for OIDC authentication
- Use existing AWS_REGION secret (or default us-west-2)
- NOT require new AWS credentials or secrets
- Use same credential pattern as terraform-deploy.yml workflow

#### Scenario: CI workflow uses existing backend configuration

**Given** smoke test needs Terraform state management
**When** terraform init runs
**Then** the system MUST:
- Use backend-ci-test.hcl for backend configuration
- Read bucket_name from config.yaml
- Store state in ci-test-{run-id}-{job-index}/terraform.tfstate key
- Use existing lock-table DynamoDB table

#### Scenario: CI workflow uses existing password secrets

**Given** smoke test needs to inject passwords into config
**When** config.yaml is prepared for deployment
**Then** the system MUST:
- Use existing ADMIN_PASSWORD secret
- Use existing DB_PASSWORD secret
- Replace PLACEHOLDER_ADMIN_PASSWORD with secret value
- Replace PLACEHOLDER_DB_PASSWORD with secret value
- NOT require new password secrets

### Requirement: Clear Test Result Reporting

The CI workflow SHALL provide clear, actionable feedback on test results, making it easy to identify which config failed and why.

**Rationale:** With 10 example configs being tested, generic failure messages are unhelpful. Maintainers need to quickly identify: which specific config failed, at what stage (plan vs deploy vs health check), and what the error was. Clear reporting reduces debugging time and speeds up issue resolution.

#### Scenario: Matrix job clearly identifies config being tested

**Given** multiple configs being tested in parallel
**When** a CI job runs
**Then** the system MUST:
- Display job name: "Terraform Plan - {config-name}" or "Deploy & Test - {config-name}"
- Show config name in all log output
- Enable filtering CI results by specific config
- Make it obvious which config passed/failed

#### Scenario: Failed terraform plan shows relevant error details

**Given** terraform plan fails for a config
**When** the CI job completes
**Then** the system MUST:
- Show the terraform plan error output
- Indicate which config file was being tested
- Highlight the specific terraform error message
- Mark the CI check as failed with descriptive status

#### Scenario: Failed deployment shows stage of failure

**Given** smoke test deployment fails
**When** the CI job completes
**Then** the system MUST:
- Indicate which stage failed: init, apply, health check, or destroy
- Show relevant error output from that stage
- Report whether cleanup (destroy) succeeded
- Provide enough context for debugging

#### Scenario: Successful test shows key metrics

**Given** smoke test deployment succeeds
**When** the CI job completes
**Then** the system MUST:
- Report deploy time (seconds to terraform apply)
- Report health check wait time
- Report destroy time
- Show allocator FQDN or IP tested
- Mark CI check as passed

## MODIFIED Requirements

None. This is a new capability with no modifications to existing requirements.

## REMOVED Requirements

None. This is purely additive functionality.

## Related Capabilities

**Configuration Validation** - Syntax validation (Level 1) is prerequisite to deployment testing
**Documentation** - Testing strategy documented in docs/TESTING_BEST_PRACTICES.md (from document-rate-limits-clean-docs change)
**Multi-Environment Deployment** - Leverages ci-test environment and backend configuration

## Dependencies

**Existing Infrastructure:**
- ci-test environment with backend-ci-test.hcl
- GitHub secrets: AWS_ROLE_ARN, AWS_REGION, ADMIN_PASSWORD, DB_PASSWORD
- S3 bucket for state storage (specified in config.yaml bucket_name)
- DynamoDB lock-table for state locking

**External Services:**
- GitHub Actions runners
- AWS EC2, S3, DynamoDB, Route53 (optional)
- Let's Encrypt staging environment (for letsencrypt config testing)

## References

- [Existing terraform-deploy.yml workflow](../../../../.github/workflows/terraform-deploy.yml) - Deployment pattern to reuse
- [ci-test backend config](../../../../lablink-infrastructure/backend-ci-test.hcl) - Backend configuration
- [Let's Encrypt Staging](https://letsencrypt.org/docs/staging-environment/) - Rate-limit-free testing environment