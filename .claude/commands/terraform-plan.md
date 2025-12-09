# Terraform Plan

Preview infrastructure changes for a specific environment before applying.

## Command Template

```bash
# Plan for ci-test environment
cd lablink-infrastructure
terraform init -backend-config=backend-ci-test.hcl
terraform plan

# Plan for test environment
terraform init -backend-config=backend-test.hcl -reconfigure
terraform plan

# Plan for production environment
terraform init -backend-config=backend-prod.hcl -reconfigure
terraform plan
```

## Usage

Ask Claude to preview changes:
```
Run terraform plan for ci-test environment
```

Or compare specific changes:
```
Show me what resources will be modified in test environment
```

## What This Command Does

Claude will:
1. Initialize Terraform with correct backend config for environment
2. Run `terraform plan` to preview changes
3. Summarize resource changes (additions, modifications, deletions)
4. Highlight cost implications (new EC2 instances, EBS volumes)
5. Flag security concerns (IAM policy changes, security group modifications)
6. Provide actionable insights before applying

## Expected Output

### Success with Changes
```
Terraform will perform the following actions:

  # aws_instance.lablink_allocator_server will be updated in-place
  ~ resource "aws_instance" "lablink_allocator_server" {
      ~ instance_type = "t3.medium" -> "t3.large"
        # (15 unchanged attributes hidden)
    }

  # aws_security_group.allow_http will be modified
  ~ resource "aws_security_group" "allow_http" {
      ~ ingress {
          + from_port = 8080
          + to_port   = 8080
            # (3 unchanged attributes hidden)
        }
    }

Plan: 0 to add, 2 to change, 0 to destroy.

💰 Cost Impact:
  - t3.medium → t3.large: +$15/month

🔒 Security Changes:
  - New ingress rule: Port 8080 (HTTP alt) from 0.0.0.0/0
  - Review: Is this port needed? Consider restricting source IPs.
```

### No Changes
```
No changes. Your infrastructure matches the configuration.

Terraform has compared your real infrastructure with your configuration
and found no differences, so no changes are needed.
```

### Warnings
```
⚠ Warning: Resource recreation required

  # aws_instance.lablink_allocator_server must be replaced
-/+ resource "aws_instance" "lablink_allocator_server" {
      ~ ami = "ami-old123" -> "ami-new456" # forces replacement

This will:
  1. Destroy the existing allocator instance
  2. Create a new instance with the new AMI
  3. Cause ~5 minutes of downtime
  4. New public IP (unless using Elastic IP)

Recommendation: Schedule this change during maintenance window.
```

## Environment-Specific Backend Configs

**dev** - `backend-dev.hcl`:
- Local state file (no S3)
- No state locking
- Use for local testing only

**ci-test** - `backend-ci-test.hcl`:
```hcl
bucket         = "tf-state-lablink-template-testing"
key            = "ci-test/terraform.tfstate"
region         = "us-west-2"
dynamodb_table = "lock-table"
encrypt        = true
```

**test** - `backend-test.hcl`:
```hcl
bucket         = "your-terraform-state-bucket"
key            = "test/terraform.tfstate"
region         = "us-west-2"
dynamodb_table = "lock-table"
encrypt        = true
```

**prod** - `backend-prod.hcl`:
```hcl
bucket         = "your-terraform-state-bucket"
key            = "prod/terraform.tfstate"
region         = "us-west-2"
dynamodb_table = "lock-table"
encrypt        = true
```

## Common Issues & Fixes

### Issue: Backend initialization failed
**Error:**
```
Error: Failed to get existing workspaces: S3 bucket does not exist.
```

**Fix:**
Create the S3 bucket first:
```bash
aws s3 mb s3://your-terraform-state-bucket --region us-west-2
aws s3api put-bucket-versioning \
  --bucket your-terraform-state-bucket \
  --versioning-configuration Status=Enabled
```

### Issue: State lock error
**Error:**
```
Error acquiring the state lock:
Lock Info:
  ID:        abc123...
  Operation: OperationTypePlan
  Who:       user@host
```

**Fix:**
Wait for other operation to complete, or force unlock (use with caution):
```bash
terraform force-unlock abc123
```

### Issue: Provider plugin errors
**Error:**
```
Error: Could not load plugin
```

**Fix:**
Reinitialize with plugin upgrade:
```bash
terraform init -upgrade -backend-config=backend-ci-test.hcl
```

### Issue: Variable not defined
**Error:**
```
Error: Reference to undeclared input variable
```

**Fix:**
Check that all variables are defined in `variables.tf` or set via `TF_VAR_` environment variables.

## Safety Checklist Before Planning

- [ ] Correct environment selected (check backend config file)
- [ ] Configuration changes reviewed
- [ ] Secrets not hardcoded (use placeholders)
- [ ] Resource names include environment suffix
- [ ] State backend accessible (S3 bucket exists)

## Understanding Plan Output

**Symbols:**
- `+` Create new resource
- `-` Destroy resource
- `~` Update in-place
- `-/+` Destroy and recreate
- `<=` Read data source

**Colors (in terminal):**
- Green: Create
- Red: Destroy
- Yellow: Modify
- Cyan: Read

**Forcing replacement:**
```
# forces replacement
```
Indicates attribute change requires destroying and recreating the resource.

## Cost Estimation

**Note:** Running `terraform plan` is FREE. It only reads your infrastructure state (minimal S3 API costs, ~$0.0004 per 1000 requests). The costs shown below are estimates for what resources **WOULD** cost if you run `terraform apply`.

Claude will estimate cost impact:

**EC2 Instances:**
- t3.small: ~$15/month
- t3.medium: ~$30/month
- t3.large: ~$60/month
- g4dn.xlarge: ~$390/month (GPU)

**EBS Volumes:**
- gp3: $0.08/GB/month
- io2: $0.125/GB/month

**Elastic IPs:**
- Associated: Free
- Unassociated: $3.60/month

## Security Review

Claude will flag:

**High Priority:**
- IAM policy changes (new permissions)
- Security group ingress from 0.0.0.0/0
- Public S3 buckets
- Unencrypted resources

**Medium Priority:**
- Instance profile changes
- Security group egress restrictions removed
- CloudWatch logging disabled

**Best Practices:**
- Tag all resources
- Use encryption by default
- Follow least privilege for IAM

## Related Commands

- `/validate-terraform` - Validate before planning
- `/terraform-apply` - Apply planned changes
- `/review-pr` - Review infrastructure PRs
- `/deploy-test` - Deploy via GitHub Actions