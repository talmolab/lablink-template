# Generate Pull Request Description

Generate a comprehensive PR description based on git commits and code changes.

## Command Template

```
Generate a PR description for the current branch based on git history and diff against main
```

## What This Command Does

Claude will:
1. Analyze `git diff main...HEAD` to see all changes
2. Review commit messages since branch divergence
3. Identify changed infrastructure files and configurations
4. Generate structured PR description
5. Format output as markdown ready for GitHub

## Manual Process

If you prefer to generate manually:

```bash
# View commits since branching from main
git log --oneline main..HEAD

# View full diff
git diff main...HEAD

# View changed files summary
git diff --stat main...HEAD

# View commit messages with details
git log --pretty=format:"%h - %s%n%b" main..HEAD
```

## PR Description Template

Claude will generate something like:

```markdown
## Summary

[1-2 sentence overview of what this PR does]

## Changes

### Infrastructure Resources
- Added/modified AWS resources in `lablink-infrastructure/main.tf`
- Updated IAM policies in `lablink-infrastructure/iam.tf`
- New security group rules in `lablink-infrastructure/security.tf`

### Configuration
- Updated `config/config.yaml` with new fields
- Added `config/prod.example.yaml` example
- Modified DNS/SSL configuration

### Scripts
- New user_data script in `lablink-infrastructure/user_data.sh`
- Updated validation script
- Added deployment automation

### Documentation
- Updated README with new deployment steps
- Added troubleshooting guide
- Updated CHANGELOG.md

## Technical Details

[Brief explanation of implementation approach, key infrastructure decisions, resource choices]

## Security Considerations

- IAM policies follow least privilege
- Security groups restrict ingress to specific IPs/ranges
- Credentials handled via environment variables/instance roles
- Encryption enabled for all data at rest

## Cost Impact

**Estimated Monthly Cost Change:**
- Instance type change: t3.medium → t3.large (+$30/month)
- New EBS volume: gp3 100GB (~$8/month)
- **Total:** +$38/month

## Testing

- [ ] Terraform validation passes (`terraform validate`)
- [ ] Terraform plan reviewed (no unexpected changes)
- [ ] Configuration validation passes (`lablink-validate-config`)
- [ ] Shellcheck validation passes
- [ ] Deployed to ci-test environment successfully
- [ ] Manual testing performed: [describe scenario]
- [ ] CI workflows pass

## Deployment Plan

1. Deploy to ci-test environment first
2. Verify health checks pass
3. Monitor logs for 24 hours
4. Deploy to production during maintenance window

## Rollback Plan

If issues occur:
1. Run `terraform apply` with previous state
2. Revert configuration changes
3. Restart services if needed

## Related Issues

Closes #[issue-number] (if applicable)
Related to #[issue-number] (if applicable)

## Checklist

- [ ] Terraform code properly formatted (`terraform fmt`)
- [ ] Configuration validated against schema
- [ ] Backend configuration correct for environment
- [ ] Documentation updated (README, CHANGELOG)
- [ ] No hardcoded secrets or credentials
- [ ] Resource tagging consistent
- [ ] Terraform plan output reviewed
- [ ] No breaking changes (or breaking changes documented)

## Terraform Plan Output

<details>
<summary>Click to expand terraform plan</summary>

```hcl
# Paste terraform plan output here
```

</details>
```

## Example Usage

### Step 1: Create feature branch
```bash
git checkout -b feat/add-iam-instance-role
# ... make changes ...
git add .
git commit -m "feat: Add IAM instance role for EC2 allocator"
git push origin feat/add-iam-instance-role
```

### Step 2: Generate PR description
```bash
# Invoke this command in Claude
# Claude will analyze your branch and generate description
```

### Step 3: Create PR with generated description
```bash
# Create PR with gh CLI
gh pr create --title "Add IAM instance role for EC2 allocator" \
  --body "$(cat pr_description.md)"

# Or copy-paste description into GitHub web interface
```

## Customizing the Description

### For Different PR Types

**Infrastructure PRs:**
```
Generate a PR description for this infrastructure change, highlighting:
- Resources added/modified
- Security implications
- Cost impact
- Deployment strategy
```

**Configuration PRs:**
```
Generate a PR description for this configuration update, including:
- What configuration changed
- Why it was needed
- Validation results
- Backward compatibility
```

**Bug Fix PRs:**
```
Generate a PR description for this infrastructure bug fix, including:
- Description of the issue
- Root cause analysis
- Fix implementation
- Verification testing
```

**Security PRs:**
```
Generate a PR description for this security improvement, explaining:
- Security vulnerability addressed
- Mitigation strategy
- Impact on existing deployments
- Compliance improvements
```

## Best Practices for PR Descriptions

### Be Specific
```
Bad:  "Fixed IAM policy"
Good: "Restricted IAM policy to allow only t3.* instance types in us-west-2"

Bad:  "Updated config"
Good: "Added DNS configuration with CloudFlare SSL support and validation"
```

### Include Context
- Why the infrastructure change was needed
- What problem it solves
- Any alternatives considered (e.g., EIP vs. DNS, ACM vs. Let's Encrypt)

### Reference Issues
```markdown
Closes #42
Fixes #38
Related to #35
```

### Show Evidence
- Terraform plan output
- Before/after resource counts
- Cost estimates
- Test deployment results

## PR Description Checklist

Ensure description includes:

- [ ] Clear summary of infrastructure changes
- [ ] Why changes were made
- [ ] Security implications reviewed
- [ ] Cost impact estimated
- [ ] How to test the changes
- [ ] Deployment strategy
- [ ] Rollback plan
- [ ] Breaking changes (if any)
- [ ] Related issues/PRs
- [ ] Testing checklist
- [ ] Terraform plan output

## Updating PR Description

If description needs updates:

```bash
# Update PR description
gh pr edit <PR_NUMBER> --body "Updated description..."

# Or append to existing description
CURRENT=$(gh pr view <PR_NUMBER> --json body -q .body)
gh pr edit <PR_NUMBER> --body "$CURRENT

## Update
[Additional information]
"
```

## For OpenSpec Changes

If PR implements an OpenSpec change:

```markdown
## OpenSpec Change

This PR implements OpenSpec change: `add-claude-dev-commands`

**Proposal**: openspec/changes/add-claude-dev-commands/proposal.md
**Tasks**: openspec/changes/add-claude-dev-commands/tasks.md

### Implementation Status

- [x] Phase 1: Validation commands
  - [x] /validate-terraform
  - [x] /validate-yaml
  - [x] /validate-bash
- [ ] Phase 2: Deployment commands (in progress)
  - [ ] /deploy-test
  - [ ] /destroy-infrastructure

See proposal for full details.
```

## Infrastructure-Specific Sections

### IAM Policy Changes

```markdown
## IAM Policy Changes

**Added Permissions:**
- `ec2:RunInstances` - Allows launching instances
- `ec2:TerminateInstances` - Allows terminating instances

**Constraints:**
- Limited to t3.* instance types
- Regional restriction: us-west-2
- Requires "ManagedBy=Terraform" tag

**Security Review:**
- Follows least privilege principle
- No wildcard resources
- Condition blocks enforce constraints
```

### Security Group Changes

```markdown
## Security Group Changes

**Ingress Rules Added:**
- Port 443 (HTTPS) from 0.0.0.0/0 - Public web access
- Port 22 (SSH) from 10.0.0.0/16 - VPC internal only

**Justification:**
- HTTPS required for public allocator access
- SSH restricted to VPC for maintenance

**Egress Rules:**
- All traffic allowed (default) - Required for package updates
```

### Configuration Schema Changes

```markdown
## Configuration Schema Changes

**New Fields:**
- `app.region` (required) - AWS region for deployment
- `dns.terraform_managed` (optional) - Whether DNS is Terraform-managed

**Breaking Changes:**
- None - all new fields have defaults or are optional

**Migration:**
- Existing configs will validate successfully
- Users should add `app.region` explicitly for clarity
```

## Related Commands

- `/review-pr` - Review a PR comprehensively
- `/update-changelog` - Update CHANGELOG for the PR
- `/terraform-plan` - Generate plan output to include in PR