# Claude Development Commands

Claude commands for streamlined LabLink infrastructure development, validation, deployment, and monitoring workflows.

## Quick Reference

| Command | Purpose | Cost |
|---------|---------|------|
| `/validate-terraform` | Check Terraform formatting and syntax | Free |
| `/validate-yaml` | Validate config files against schema | Free |
| `/validate-bash` | Check shell scripts with shellcheck | Free |
| `/terraform-plan` | Preview infrastructure changes | Free* |
| `/review-pr` | Comprehensive PR review | Free |
| `/pr-description` | Generate PR description from git history | Free |
| `/update-changelog` | Update CHANGELOG.md | Free |

*Terraform plan incurs minimal S3 read costs (~$0.0004 per 1000 requests)

## Command Categories

### Validation Commands

**Use these before committing changes:**

- **[/validate-terraform](validate-terraform.md)** - Validate Terraform code
  - Checks formatting with `terraform fmt -check`
  - Validates syntax with `terraform validate`
  - Reports errors with file:line references
  - Provides fix suggestions

- **[/validate-yaml](validate-yaml.md)** - Validate configuration files
  - Validates against LabLink schema using Docker
  - Checks required fields and value constraints
  - Reports clear error messages with field paths
  - Suggests fixes based on example configs

- **[/validate-bash](validate-bash.md)** - Validate shell scripts
  - Runs shellcheck on all `.sh` files
  - Reports findings by severity (error, warning, info, style)
  - Provides fix examples and wiki links
  - Enforces best practices

### Planning & Review Commands

**Use these for infrastructure changes:**

- **[/terraform-plan](terraform-plan.md)** - Preview infrastructure changes
  - Initializes Terraform with correct backend
  - Shows resource additions, modifications, deletions
  - Estimates cost impact
  - Flags security concerns
  - **Note:** Running plan is free; costs shown are for `terraform apply`

- **[/review-pr](review-pr.md)** - Comprehensive PR review
  - Fetches PR details and all comments
  - Analyzes infrastructure best practices
  - Checks security (IAM, security groups, credentials)
  - Validates Terraform formatting and structure
  - Posts categorized feedback via gh CLI

- **[/pr-description](pr-description.md)** - Generate PR descriptions
  - Analyzes git diff against main branch
  - Reviews commit messages for context
  - Generates structured description with:
    - Summary of infrastructure changes
    - Security considerations
    - Cost impact estimation
    - Deployment and rollback plans
    - Testing checklist

### Documentation Commands

**Use these for release management:**

- **[/update-changelog](update-changelog.md)** - Update CHANGELOG.md
  - Analyzes git history since last release
  - Categorizes changes (Added, Changed, Fixed, Infrastructure, Security)
  - Generates entries following Keep a Changelog format
  - References PRs and issues
  - Includes cost and breaking change notes

## Typical Workflows

### Before Committing Changes

```bash
# Validate everything locally
/validate-terraform
/validate-yaml
/validate-bash

# Fix any issues reported
# Then commit
git add .
git commit -m "feat: Add IAM instance role"
```

### Before Creating a PR

```bash
# Preview infrastructure changes
/terraform-plan ci-test

# Generate PR description
/pr-description

# Create PR with generated description
gh pr create --title "Add IAM instance role" --body "$(cat pr_description.md)"
```

### Reviewing a PR

```bash
# Comprehensive review with planning mode
/review-pr 25

# Claude will:
# - Fetch PR and all comments
# - Analyze infrastructure changes
# - Check security implications
# - Post structured review
```

### Preparing a Release

```bash
# Update CHANGELOG based on merged PRs
/update-changelog

# Review generated entries
# Tag the release
git tag -a v1.1.0 -m "Release 1.1.0"
git push --tags
```

## Command Documentation

Each command has detailed documentation including:
- Command syntax and usage examples
- Expected output for success and failure cases
- Troubleshooting guidance for common issues
- Related commands
- CI integration examples

Click on any command link above to see full documentation.

## Tool Requirements

These commands use standard development tools:

| Tool | Purpose | Installation |
|------|---------|-------------|
| `terraform` | Infrastructure as code | [terraform.io](https://terraform.io) |
| `docker` | Config validation | [docker.com](https://docker.com) |
| `shellcheck` | Bash validation | `brew install shellcheck` |
| `gh` | GitHub CLI | `brew install gh` or [cli.github.com](https://cli.github.com) |
| `git` | Version control | Pre-installed on most systems |

## CI Integration

All validation commands run automatically in GitHub Actions:

### Config Validation
```yaml
name: Validate Configuration
on: [pull_request]
jobs:
  validate:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - name: Validate config.yaml
        run: |
          docker run --rm -v "$(pwd)":/workspace \
            ghcr.io/talmolab/lablink-validate-config:latest \
            /workspace/lablink-infrastructure/config/config.yaml
```

### Terraform Validation
```yaml
- name: Terraform Format Check
  run: terraform fmt -check -recursive lablink-infrastructure/

- name: Terraform Validate
  run: |
    cd lablink-infrastructure
    terraform init -backend=false
    terraform validate
```

See `.github/workflows/` for full CI configuration.

## Getting Help

### Command Help
Each command file has comprehensive documentation with:
- Usage examples
- Expected output
- Common issues and fixes
- Related commands

### Project Help
- **Issues**: [github.com/talmolab/lablink-template/issues](https://github.com/talmolab/lablink-template/issues)
- **Discussions**: [github.com/talmolab/lablink-template/discussions](https://github.com/talmolab/lablink-template/discussions)
- **Documentation**: See [README.md](../../README.md)

## Best Practices

### Validate Early and Often
Run validation commands frequently during development:
```bash
# After every significant change
/validate-terraform && /validate-yaml && /validate-bash
```

### Review Terraform Plans
Always review plans before applying:
```bash
# Generate plan for review
/terraform-plan ci-test

# Review output carefully for:
# - Unexpected resource changes
# - Security implications
# - Cost impact
```

### Use Planning Mode for Reviews
When reviewing complex PRs:
```bash
# Enable planning mode and ultrathink
Review PR #25 using planning mode and ultrathink
```

### Keep CHANGELOG Updated
Update CHANGELOG with every significant PR:
```bash
# After merging PR
/update-changelog

# Review and commit
git add CHANGELOG.md
git commit -m "docs: Update CHANGELOG for v1.1.0"
```

## Contributing

To add new Claude commands:

1. Create a new `.md` file in `.claude/commands/`
2. Follow the existing template structure:
   - Command Template
   - What This Command Does
   - Usage
   - Expected Output
   - Common Issues & Fixes
   - Related Commands
3. Add entry to this README
4. Update OpenSpec if adding significant new capabilities

## OpenSpec Integration

These commands were implemented via OpenSpec change proposal:
- **Proposal**: `openspec/changes/add-claude-dev-commands/proposal.md`
- **Tasks**: `openspec/changes/add-claude-dev-commands/tasks.md`
- **Specs**: `openspec/changes/add-claude-dev-commands/specs/`

For major command additions or changes, follow the OpenSpec workflow.