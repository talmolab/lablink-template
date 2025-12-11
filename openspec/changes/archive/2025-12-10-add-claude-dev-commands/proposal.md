# Add Claude Development Commands

## Problem

Developers working on lablink-template need quick access to common development workflows like reviewing PRs, validating Terraform/YAML/Bash, running Docker builds, generating PR descriptions, and deploying infrastructure. Currently, these workflows require remembering complex multi-step commands and GitHub CLI syntax.

The gapit3-gwas-pipeline repository has established a comprehensive set of Claude commands that streamline development workflows. We need similar commands adapted for lablink-template's infrastructure-focused tech stack.

## Proposed Solution

Add a set of Claude slash commands (`.claude/commands/*.md`) tailored to lablink-template development workflows:

### Core Development Commands

1. **`/validate-terraform`** - Run `terraform fmt -check` and `terraform validate` on infrastructure code
2. **`/validate-yaml`** - Run `lablink-validate-config` on config files
3. **`/validate-bash`** - Run `shellcheck` on all shell scripts
4. **`/terraform-plan`** - Run `terraform plan` for a specific environment with proper backend initialization
5. **`/terraform-apply`** - Apply Terraform changes with confirmation and safety checks

### CI/CD Commands

6. **`/deploy-test`** - Trigger GitHub Actions deployment workflow for ci-test environment
7. **`/deploy-prod`** - Trigger production deployment with extra safety confirmations
8. **`/destroy-infrastructure`** - Safely destroy infrastructure for an environment

### PR & Review Commands

9. **`/review-pr`** - Comprehensive PR review with planning mode and ultrathink (adapted from gapit3)
10. **`/pr-description`** - Generate structured PR description from git history (adapted from gapit3)

### Infrastructure Monitoring Commands

11. **`/check-infrastructure`** - Verify deployed infrastructure health (HTTP checks, DNS, SSL)
12. **`/view-logs`** - Fetch and display CloudWatch logs for allocator or client VMs

### Docker Commands

13. **`/docker-build-allocator`** - Build allocator Docker image locally
14. **`/docker-build-client`** - Build client VM Docker image locally

### Documentation Commands

15. **`/update-changelog`** - Update CHANGELOG.md based on recent changes (adapted from gapit3)

## Benefits

- **Faster development cycles** - Common tasks accessible via `/command` instead of remembering syntax
- **Consistency** - Standardized workflows across all developers
- **Lower barrier to entry** - New contributors don't need to learn all CLI tools
- **Reduced errors** - Commands include safety checks and validation steps
- **Better documentation** - Commands serve as executable documentation of workflows

## Success Criteria

- [ ] All 15 commands implemented and documented
- [ ] Commands tested in real development scenarios
- [ ] Documentation updated to reference commands
- [ ] Commands follow conventions from gapit3-gwas-pipeline
- [ ] Each command includes:
  - Clear description of purpose
  - Usage examples
  - Expected output
  - Troubleshooting section
  - Related commands

## Scope

**In scope:**
- Creating `.claude/commands/` directory structure
- Writing 15 command markdown files
- Adapting gapit3 commands where applicable
- Creating lablink-specific commands for infrastructure workflows
- Updating project documentation to mention commands

**Out of scope:**
- Creating new OpenSpec commands (those already exist in `.claude/commands/openspec/`)
- Modifying existing GitHub Actions workflows
- Creating new CI/CD infrastructure
- Changing Terraform code structure

## Dependencies

- Existing `.claude/commands/openspec/` directory
- GitHub CLI (`gh`) installed and authenticated
- Terraform CLI available
- `lablink-validate-config` tool installed
- `shellcheck` installed for bash validation

## Alternatives Considered

1. **No standardized commands** - Continue with ad-hoc command execution
   - Rejected: Increases cognitive load, slows development

2. **Makefile-based approach** - Use Make targets instead of Claude commands
   - Rejected: Less discoverable, doesn't integrate with Claude Code interface

3. **Shell scripts in `scripts/` directory** - Create wrapper scripts
   - Rejected: Less integrated with Claude Code workflow, harder to discover

## Open Questions

None - this is a straightforward enhancement following established patterns.