# Review GitHub Pull Request

Comprehensively review a GitHub Pull Request with planning mode, ultrathink analysis, and automated feedback posting.

## Command Template

```
Review PR #<NUMBER> using planning mode and ultrathink.

Steps:
1. Fetch PR details and all comments
2. Analyze code changes thoroughly
3. Post comprehensive review via gh CLI
```

## Usage

```bash
# Get PR number
gh pr list

# Review specific PR (replace <PR_NUMBER>)
# Then invoke this command and Claude will:
# - Use planning mode for structured analysis
# - Enable ultrathink for deep reasoning
# - Read all existing PR comments and reviews
# - Analyze code changes for correctness, style, and best practices
# - Post review feedback via gh CLI
```

## What This Command Does

### 1. Fetch PR Information

```bash
# View PR with all comments
gh pr view <PR_NUMBER> --comments

# Get inline code review comments
gh api repos/:owner/:repo/pulls/<PR_NUMBER>/comments \
  --jq '.[] | {path: .path, line: .line, body: .body}'

# Get review summaries
gh api repos/:owner/:repo/pulls/<PR_NUMBER>/reviews \
  --jq '.[].body'

# Get PR diff
gh pr diff <PR_NUMBER>
```

### 2. Analysis with Planning Mode & Ultrathink

The review uses:
- **Planning mode**: Structured approach to reviewing code systematically
- **Ultrathink**: Deep analysis of logic, edge cases, and potential issues

Review categories:
- **Correctness**: Logic errors, bugs, edge cases
- **Security**: IAM policies, security groups, public access, credentials handling
- **Infrastructure best practices**: Terraform structure, state management, resource tagging
- **Cost implications**: Instance types, storage, data transfer
- **Reliability**: High availability, backup/recovery, monitoring
- **Configuration**: YAML schema compliance, proper placeholders
- **Testing**: Validation before deployment

### 3. Post Review via gh CLI

```bash
# Post review comment
gh pr review <PR_NUMBER> --comment --body "$(cat <<'EOF'
## Infrastructure Code Review

### Summary
[High-level overview of changes and assessment]

### Strengths
- Well-structured Terraform code
- Comprehensive validation
- Clear documentation

### Issues Found

#### Critical
- [Issue description with file:line reference]

#### Important
- [Issue description with file:line reference]

#### Minor/Suggestions
- [Suggestion with rationale]

### Security Considerations
- [IAM policy review]
- [Security group analysis]
- [Credential handling]

### Cost Impact
- [Estimated monthly cost changes]

### Recommendations
1. [Action item]
2. [Action item]

### Questions
- [Clarification needed]
EOF
)"

# Or approve PR
gh pr review <PR_NUMBER> --approve --body "LGTM! ..."

# Or request changes
gh pr review <PR_NUMBER> --request-changes --body "Please address: ..."
```

## Example Workflow

### Step 1: List PRs
```bash
gh pr list
```

Output:
```
#25  feat: Add IAM instance role  feat/iam-instance-role
#19  fix: Update security groups   fix/security-group-ports
```

### Step 2: Review PR in Claude
Invoke this command and tell Claude:

```
Review PR #25 using planning mode and ultrathink
```

### Step 3: Claude's Analysis Process

Claude will:
1. **Fetch all data**:
   - PR description and metadata
   - All existing comments and reviews
   - Full code diff
   - Related configuration files for context

2. **Plan the review** (planning mode):
   - Identify infrastructure files to review
   - Prioritize critical vs minor issues
   - Structure feedback categories

3. **Deep analysis** (ultrathink):
   - Trace Terraform resource dependencies
   - Identify security implications
   - Check against AWS best practices
   - Verify configuration schema compliance
   - Estimate cost impact

4. **Post structured review**:
   - Clear categorization of issues
   - File:line references for each issue
   - Actionable recommendations
   - Security and cost assessment
   - Overall approval/request changes

## Review Checklist

The command ensures these are checked:

### Infrastructure Security
- [ ] IAM policies follow least privilege
- [ ] Security groups restrict ingress appropriately
- [ ] No hardcoded credentials
- [ ] Encryption enabled (EBS, S3, RDS)
- [ ] Public access justified and documented
- [ ] Instance metadata service v2 enabled

### Terraform Best Practices
- [ ] Proper formatting (`terraform fmt`)
- [ ] Valid syntax (`terraform validate`)
- [ ] Resources properly tagged
- [ ] Environment-specific naming
- [ ] Backend configuration correct
- [ ] Provider versions pinned
- [ ] No sensitive data in state

### Configuration Validation
- [ ] YAML passes `lablink-validate-config`
- [ ] Required fields present
- [ ] Enum values valid
- [ ] Placeholders used for secrets
- [ ] DNS/SSL configuration valid
- [ ] Region matches backend config

### Cost & Performance
- [ ] Instance types appropriate for workload
- [ ] Storage sizing justified
- [ ] EIP usage necessary
- [ ] Data transfer costs considered
- [ ] Reserved instances where applicable

### Reliability & Monitoring
- [ ] Health checks configured
- [ ] Logging enabled (CloudWatch)
- [ ] Backup strategy in place
- [ ] Disaster recovery considered
- [ ] Alerting configured

### Documentation
- [ ] README updated if needed
- [ ] CHANGELOG entry added
- [ ] Configuration examples provided
- [ ] Deployment instructions clear

### Testing & Validation
- [ ] CI validation passes
- [ ] `terraform plan` reviewed
- [ ] Tested in ci-test environment
- [ ] Rollback plan documented

## Addressing Review Comments

After Claude posts review:

### For PR Author

```bash
# View review comments
gh pr view <PR_NUMBER> --comments

# Make fixes based on feedback
# ... edit files ...

# Commit and push
git add .
git commit -m "fix: Address review feedback - restrict IAM permissions"
git push

# Reply to review
gh pr comment <PR_NUMBER> --body "Addressed all feedback:
- Restricted IAM policy to specific instance types
- Added regional constraint to us-west-2
- Updated security group to specific IP ranges
- Added terraform plan output to PR description
"
```

### For Reviewer (Follow-up)

```bash
# Check if issues addressed
gh pr diff <PR_NUMBER>

# Post follow-up review
gh pr review <PR_NUMBER> --comment --body "Thanks for the fixes! LGTM now."

# Or approve
gh pr review <PR_NUMBER> --approve --body "All feedback addressed. Security concerns resolved. Approving!"
```

## Advanced Options

### Review Specific Files Only

Tell Claude:
```
Review PR #25, focusing only on Terraform changes in lablink-infrastructure/
```

### Review for Specific Concerns

Tell Claude:
```
Review PR #25 for security vulnerabilities and IAM policy issues
```

### Compare Against Issue Requirements

Tell Claude:
```
Review PR #25 and verify it addresses all requirements from issue #14
```

## gh CLI Setup

Install gh CLI if needed:

```bash
# macOS
brew install gh

# Linux
curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg | sudo dd of=/usr/share/keyrings/githubcli-archive-keyring.gpg
echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" | sudo tee /etc/apt/sources.list.d/github-cli.list > /dev/null
sudo apt update
sudo apt install gh

# Windows
winget install --id GitHub.cli

# Authenticate
gh auth login
```

## Common Infrastructure Review Patterns

### IAM Policy Review
```
Check for:
- Wildcard actions (*) - should be specific
- Resource: "*" - should be constrained
- Effect: "Allow" with overly broad permissions
- Missing condition blocks for extra security
```

### Security Group Review
```
Check for:
- Ingress from 0.0.0.0/0 - should be specific IPs/ranges
- Unnecessary port ranges
- Missing egress restrictions
- Documentation for why ports are open
```

### Terraform State Review
```
Check for:
- Backend configuration matches environment
- State locking enabled (DynamoDB)
- Encryption enabled
- No sensitive data in resource names
```

## Related Commands

- `/pr-description` - Generate PR description
- `/update-changelog` - Update CHANGELOG based on PR
- `/terraform-plan` - Preview infrastructure changes
- `/validate-terraform` - Validate Terraform before review
- `/validate-yaml` - Validate configuration before review