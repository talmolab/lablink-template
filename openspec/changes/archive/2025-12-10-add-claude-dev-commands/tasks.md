# Tasks: Add Claude Development Commands

## Phase 1: Validation Commands (High Priority)

### 1.1 Create `/validate-terraform` command
- [ ] Write `.claude/commands/validate-terraform.md`
- [ ] Include `terraform fmt -check` for all .tf files
- [ ] Include `terraform validate` with proper initialization
- [ ] Add examples for different environments (dev, test, prod)
- [ ] Document expected output and error handling
- [ ] Test command in lablink-infrastructure directory

### 1.2 Create `/validate-yaml` command
- [ ] Write `.claude/commands/validate-yaml.md`
- [ ] Use `lablink-validate-config` on config files
- [ ] Include validation for all example configs
- [ ] Add troubleshooting for common validation errors
- [ ] Test with valid and invalid YAML files

### 1.3 Create `/validate-bash` command
- [ ] Write `.claude/commands/validate-bash.md`
- [ ] Run `shellcheck` on all .sh files
- [ ] Include shellcheck severity levels (error, warning, info)
- [ ] Add examples of fixing common shellcheck issues
- [ ] Test on `user_data.sh` and other scripts

## Phase 2: Terraform Workflow Commands (High Priority)

### 2.1 Create `/terraform-plan` command
- [ ] Write `.claude/commands/terraform-plan.md`
- [ ] Include backend initialization with correct hcl file
- [ ] Support all environments (dev, test, prod, ci-test)
- [ ] Add resource change summary interpretation
- [ ] Include safety checks before planning
- [ ] Test plan generation for each environment

### 2.2 Create `/terraform-apply` command
- [ ] Write `.claude/commands/terraform-apply.md`
- [ ] Include confirmation prompts and warnings
- [ ] Add pre-apply validation steps
- [ ] Document when to use auto-approve (CI only)
- [ ] Include rollback guidance
- [ ] Test apply in dev environment only

## Phase 3: PR & Review Commands (Medium Priority)

### 3.1 Adapt `/review-pr` command from gapit3
- [ ] Copy `review-pr.md` template from gapit3
- [ ] Adapt checklist for infrastructure code (Terraform, YAML, Bash, Python)
- [ ] Update review categories (infrastructure security, IAM policies, cost implications)
- [ ] Add lablink-specific concerns (DNS configuration, SSL setup, environment isolation)
- [ ] Remove R-specific sections
- [ ] Test on actual PR in lablink-template

### 3.2 Adapt `/pr-description` command from gapit3
- [ ] Copy `pr-description.md` template from gapit3
- [ ] Adapt template for infrastructure PRs
- [ ] Include sections for: configuration changes, resource modifications, security implications
- [ ] Add infrastructure testing checklist
- [ ] Remove R/statistical analysis sections
- [ ] Test with feature branch

### 3.3 Adapt `/update-changelog` command from gapit3
- [ ] Copy `update-changelog.md` template from gapit3
- [ ] Adapt for infrastructure changelog format
- [ ] Include infrastructure-specific categories (Added Resources, Changed Configs, Security Updates)
- [ ] Test changelog generation

## Phase 4: CI/CD Commands (Medium Priority)

### 4.1 Create `/deploy-test` command
- [ ] Write `.claude/commands/deploy-test.md`
- [ ] Use `gh workflow run` to trigger deployment
- [ ] Include status monitoring with `gh run watch`
- [ ] Add troubleshooting for common deployment failures
- [ ] Test triggering ci-test deployment

### 4.2 Create `/deploy-prod` command
- [ ] Write `.claude/commands/deploy-prod.md`
- [ ] Include multiple confirmation prompts
- [ ] Add pre-deployment checklist (tests pass, PR approved, config validated)
- [ ] Require explicit --confirm flag
- [ ] Test command structure (but not actual production deployment)

### 4.3 Create `/destroy-infrastructure` command
- [ ] Write `.claude/commands/destroy-infrastructure.md`
- [ ] Include environment-specific safety checks
- [ ] Prevent accidental production destruction
- [ ] Add data backup reminders (S3, DynamoDB)
- [ ] Use `gh workflow run terraform-destroy.yml`
- [ ] Test in dev environment only

## Phase 5: Monitoring Commands (Low Priority)

### 5.1 Create `/check-infrastructure` command
- [ ] Write `.claude/commands/check-infrastructure.md`
- [ ] Include HTTP connectivity tests
- [ ] Add DNS resolution checks
- [ ] Include SSL certificate validation
- [ ] Add EC2 instance status checks via AWS CLI
- [ ] Test health checks on ci-test environment

### 5.2 Create `/view-logs` command
- [ ] Write `.claude/commands/view-logs.md`
- [ ] Use AWS CLI to fetch CloudWatch logs
- [ ] Support filtering by time range
- [ ] Include both allocator and client VM logs
- [ ] Add log stream selection
- [ ] Test log retrieval from ci-test

## Phase 6: Docker Commands (Low Priority)

### 6.1 Create `/docker-build-allocator` command
- [ ] Write `.claude/commands/docker-build-allocator.md`
- [ ] Include GitHub Container Registry push steps
- [ ] Add image tagging best practices
- [ ] Document build arguments
- [ ] Test local Docker build (if allocator Dockerfile exists in template)

### 6.2 Create `/docker-build-client` command
- [ ] Write `.claude/commands/docker-build-client.md`
- [ ] Include GHCR push workflow
- [ ] Add GPU driver considerations
- [ ] Document custom AMI creation
- [ ] Test build process

## Phase 7: Documentation & Polish (Final)

### 7.1 Update project README
- [ ] Add "Claude Commands" section to README.md
- [ ] List all available commands with brief descriptions
- [ ] Link to `.claude/commands/` directory
- [ ] Add quick start guide for using commands

### 7.2 Create command index
- [ ] Create `.claude/commands/README.md`
- [ ] Organize commands by category
- [ ] Include usage tips and best practices
- [ ] Add command dependencies (required tools)

### 7.3 Validate all commands
- [ ] Test each command in real development workflow
- [ ] Verify all examples work as documented
- [ ] Check cross-references between commands
- [ ] Ensure consistent formatting and structure

## Validation Criteria

Each command must:
- Include clear description and purpose
- Provide working code examples
- Document expected output
- Include troubleshooting section
- Reference related commands
- Follow markdown formatting standards

## Dependencies

- `gh` CLI installed and authenticated
- Terraform CLI available
- AWS CLI configured (for monitoring commands)
- `lablink-validate-config` installed
- `shellcheck` installed
- Docker installed (for Docker commands)

## Estimated Effort

- Phase 1 (Validation): 3-4 hours
- Phase 2 (Terraform): 4-5 hours
- Phase 3 (PR/Review): 2-3 hours (adapting existing)
- Phase 4 (CI/CD): 3-4 hours
- Phase 5 (Monitoring): 2-3 hours
- Phase 6 (Docker): 2-3 hours
- Phase 7 (Documentation): 1-2 hours

**Total: 17-24 hours** (2-3 working days)

## Success Metrics

- [ ] All 15 commands implemented
- [ ] Commands successfully tested in development
- [ ] Documentation updated
- [ ] At least 3 developers have used commands
- [ ] Zero critical bugs reported after 1 week of use