# Update CHANGELOG

Maintain the project CHANGELOG.md following Keep a Changelog format.

## Command Template

```
Update CHANGELOG.md based on recent changes. Review git commits since last release and categorize changes.
```

## CHANGELOG Format

The project follows [Keep a Changelog](https://keepachangelog.com/en/1.0.0/) format:

```markdown
# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added
- New features that have been added

### Changed
- Changes to existing functionality

### Fixed
- Bug fixes

### Infrastructure
- Infrastructure and deployment changes

### Security
- Security fixes and improvements

## [1.0.0] - 2025-01-15

### Added
- Initial release
- LabLink infrastructure as code
```

## When to Update CHANGELOG

Update CHANGELOG when:
- Adding new infrastructure resources
- Modifying Terraform configurations
- Fixing deployment issues
- Making security improvements
- Updating configuration schema
- Adding new Claude commands
- Improving documentation (if substantial)

## Manual Update Process

### Step 1: Review Recent Changes

```bash
# View commits since last tag
git log --oneline $(git describe --tags --abbrev=0)..HEAD

# Or view commits since specific date
git log --oneline --since="2025-01-01"

# Or view diff since last tag
git diff $(git describe --tags --abbrev=0)..HEAD --stat

# Or view merged PRs
gh pr list --state merged --limit 20
```

### Step 2: Categorize Changes

Determine category for each change:

**Added** - New features and resources:
- New AWS resources (EC2, IAM, security groups)
- New configuration options
- New Claude commands
- New documentation sections

**Changed** - Modifications to existing infrastructure:
- Updated instance types
- Modified security group rules
- Enhanced deployment workflows
- Improved validation

**Fixed** - Bug fixes:
- Corrected Terraform errors
- Fixed deployment failures
- Resolved configuration issues
- Fixed edge cases

**Infrastructure** - Infrastructure-specific changes:
- Terraform state management updates
- Backend configuration changes
- Resource tagging improvements
- Cost optimization

**Security** - Security improvements:
- IAM policy hardening
- Security group restrictions
- Credential handling improvements
- Encryption enablement

### Step 3: Write Entry

```markdown
## [Unreleased]

### Added
- IAM instance role for EC2 allocator with scoped permissions (#19)
- CloudWatch monitoring with alarms and metric filters (#20)
- Claude development commands for streamlined workflows (#25)
- Docker validation for config files via `lablink-validate-config`

### Changed
- Updated security groups to restrict ingress to specific IP ranges (#18)
- Improved Terraform validation in CI workflows
- Enhanced configuration schema with DNS and SSL options

### Fixed
- Corrected EIP association timing in user_data script (#15)
- Fixed backend configuration path resolution for Windows
- Resolved DNS propagation issues with CloudFlare

### Infrastructure
- Migrated to Terraform 1.9+ with enhanced state management
- Added DynamoDB state locking for all environments
- Implemented resource tagging strategy (Environment, ManagedBy, Project)

### Security
- Restricted IAM policies to specific instance types and regions (#19)
- Enabled encryption for all EBS volumes and S3 buckets
- Implemented instance metadata service v2 (IMDSv2)
```

## Categories Explained

### Added
```markdown
### Added
- IAM instance role with scoped EC2 launch permissions
- CloudWatch log groups with 30-day retention
- Elastic IP allocation for stable public addressing
- Let's Encrypt SSL certificate automation
```

### Changed
```markdown
### Changed
- Updated allocator instance type from t3.medium to t3.large
- Improved user_data script with better error handling
- Enhanced CI validation to include shellcheck and config validation
- Migrated from manual DNS to Terraform-managed Route53
```

### Fixed
```markdown
### Fixed
- Fixed Terraform state lock timeout on concurrent deployments
- Corrected security group rule priority ordering
- Resolved CloudWatch agent installation failures on Ubuntu 24.04
- Fixed config validation rejecting valid domain names with hyphens
```

### Infrastructure
```markdown
### Infrastructure
- Reorganized Terraform modules for better reusability
- Implemented multi-environment backend configuration (dev/ci-test/test/prod)
- Added Terraform plan validation to GitHub Actions
- Introduced resource lifecycle management for stateful resources
```

### Security
```markdown
### Security
- Restricted IAM RunInstances to t3.* instance family only
- Added regional constraint to IAM policies (us-west-2)
- Enforced IMDSv2 for instance metadata access
- Enabled S3 bucket versioning and encryption
```

## Release Process

When ready to release a version:

### Step 1: Move Unreleased to Versioned

```markdown
## [Unreleased]

(Leave empty or add future planned items)

## [1.1.0] - 2025-01-15

### Added
- (move items from Unreleased here)

### Changed
- (move items from Unreleased here)

### Fixed
- (move items from Unreleased here)

### Infrastructure
- (move items from Unreleased here)

### Security
- (move items from Unreleased here)
```

### Step 2: Update Version

Follow [Semantic Versioning](https://semver.org/):

- **MAJOR** (1.0.0 -> 2.0.0): Breaking changes (config schema breaking changes, resource replacements)
- **MINOR** (1.0.0 -> 1.1.0): New features (new resources, new config options, backward compatible)
- **PATCH** (1.0.0 -> 1.0.1): Bug fixes (bug fixes, security patches, backward compatible)

### Step 3: Create Git Tag

```bash
# Tag the release
git tag -a v1.1.0 -m "Release version 1.1.0

- Added IAM instance role
- Enhanced security controls
- Improved monitoring
"

# Push tag
git push origin v1.1.0

# Or push all tags
git push --tags
```

## Best Practices

### Be User-Focused

```markdown
Good: "Added IAM instance role to eliminate need for static AWS credentials"
Bad:  "Refactored IAM implementation"

Good: "Fixed allocator failing to start when DNS propagation takes >5 minutes"
Bad:  "Fixed timing bug"
```

### Include Context

```markdown
Good: "Updated instance type to t3.large for 40% better performance on high-load scenarios"
Bad:  "Updated instance type"

Good: "Deprecated IP-only access; DNS required starting v2.0.0 (provides SSL, easier discovery)"
Bad:  "Deprecated IP access"
```

### Reference PRs and Issues

```markdown
### Added
- IAM instance role for secure credential management (#19)
- CloudWatch monitoring with cost and error alarms (#20)

### Fixed
- Corrected security group ingress rules for HTTPS traffic (fixes #18)
- Resolved Terraform state lock contention on rapid deployments (#22)
```

### Specify Infrastructure Impact

```markdown
### Changed
- Updated security groups:
  - Restricted SSH (port 22) to VPC CIDR only
  - Added HTTPS (port 443) for public access
  - Removed HTTP (port 80) - HTTPS required
  **Impact:** Existing deployments need manual security group update
```

### Include Cost Impact (if significant)

```markdown
### Changed
- Upgraded default instance type from t3.medium to t3.large (+$30/month)
- Added CloudWatch Logs with 30-day retention (~$5/month per environment)
  **Cost Impact:** +$35/month per environment
```

## Quick Commands

```bash
# View commits for CHANGELOG entry
git log --oneline --no-merges v1.0.0..HEAD

# Count commits by type (conventional commits)
git log --oneline v1.0.0..HEAD | grep -c "^[a-f0-9]* feat:"
git log --online v1.0.0..HEAD | grep -c "^[a-f0-9]* fix:"

# Generate commit list
git log --pretty=format:"- %s (%h)" v1.0.0..HEAD

# List merged PRs since date
gh pr list --state merged --search "merged:>2025-01-01"

# View specific PR details for CHANGELOG
gh pr view 19 --json title,body,labels
```

## Infrastructure-Specific Guidance

### For Resource Changes

```markdown
### Added
- `aws_iam_role.allocator_instance_role` - Instance role for EC2 allocator
- `aws_iam_role_policy_attachment.allocator_ec2_policy` - Scoped EC2 permissions
- `aws_cloudwatch_log_group.allocator_logs` - Centralized logging
```

### For Configuration Schema Changes

```markdown
### Changed
- Configuration schema version 1.1:
  - Added `app.region` (required) - AWS region for deployment
  - Added `dns.terraform_managed` (optional, default: true)
  - Deprecated `dns.manual_setup` (use `terraform_managed: false` instead)
```

### For Deployment Changes

```markdown
### Changed
- Deployment workflow now validates Terraform and config before apply
- Added manual approval step for production deployments
- Deployment now waits for health checks before reporting success
```

## CHANGELOG Location

- **File**: `CHANGELOG.md` (project root)
- **Format**: Markdown
- **Sections**: Sorted by version (newest first)

## Verification

After updating:

```bash
# Verify markdown syntax
# (Can use markdownlint or similar)

# Check that version numbers follow semver
# Check that dates are in YYYY-MM-DD format
# Ensure each entry is actionable and user-focused
# Verify PR/issue references are valid
```

## Related Commands

- `/pr-description` - Generate PR descriptions (source for CHANGELOG entries)
- `/review-pr` - Review PRs (may identify CHANGELOG-worthy changes)