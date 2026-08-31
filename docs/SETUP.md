# Setup and Workflow Reference

Detailed reference for **Path B** (this template + GitHub Actions): what the AWS
prerequisites are, how OIDC authentication works, how to create every resource by
hand if you prefer, and what inputs the deploy/destroy workflows take.

For the 5-minute happy path, see the [README](../README.md). For configuration
options, see the [configuration guide](../lablink-infrastructure/config/README.md).

---

## Prerequisites

### Required

- **AWS Account** with permissions to create:
  - EC2 instances
  - Security Groups
  - Elastic IPs
  - (Optional) Route 53 records for DNS

- **GitHub Account** with ability to:
  - Create repositories from templates
  - Configure GitHub Actions secrets
  - Run GitHub Actions workflows

- **Basic Knowledge** of:
  - OpenTofu (helpful but not required)
  - AWS services

### AWS Setup Required

Before deploying, you must set up:

1. **S3 Bucket** for OpenTofu state storage
2. **IAM Role** for GitHub Actions OIDC authentication
3. **(Optional) Elastic IP** for persistent allocator address
4. **(Optional) Route 53 Hosted Zone** for custom domain

See [AWS Setup Guide](#aws-setup-guide) below for detailed instructions.

## GitHub Secrets Setup

### Why OIDC instead of long-lived AWS keys?

The deploy and destroy workflows authenticate to AWS using [OpenID Connect (OIDC)](https://docs.github.com/en/actions/deployment/security-hardening-your-deployments/about-security-hardening-with-openid-connect) rather than static `AWS_ACCESS_KEY_ID` / `AWS_SECRET_ACCESS_KEY` secrets. The flow at deploy time looks like:

1. GitHub Actions issues a short-lived JSON Web Token (JWT) for the running workflow, signed by `token.actions.githubusercontent.com`.
2. The workflow calls `sts:AssumeRoleWithWebIdentity` against the IAM role you registered (`AWS_ROLE_ARN`).
3. AWS validates the JWT against the OIDC provider trust policy (which restricts which `repo:ORG/REPO:*` subject can assume the role) and returns temporary credentials.
4. OpenTofu uses those temporary credentials for the duration of the job — typically an hour or less — then they expire.

**Why this matters:**
- No long-lived AWS keys ever live in GitHub secrets, so a compromised repository secret cannot be replayed indefinitely.
- The trust policy pins the role to your specific repository (and optionally a branch/environment), so other repos in your org can't assume it by accident.
- Credentials auto-rotate every workflow run — there is no key to rotate manually.

`./scripts/setup.sh` creates the OIDC provider, the IAM role with the correct trust policy, and writes the role ARN to the `AWS_ROLE_ARN` GitHub secret for you. The manual steps below are for users who prefer to wire this up themselves.

### AWS_ROLE_ARN

Create an IAM role with OIDC provider for GitHub Actions:

1. Create OIDC provider in IAM (if not exists):
   - Provider URL: `https://token.actions.githubusercontent.com`
   - Audience: `sts.amazonaws.com`

2. Create IAM role with trust policy:
   ```json
   {
     "Version": "2012-10-17",
     "Statement": [
       {
         "Effect": "Allow",
         "Principal": {
           "Federated": "arn:aws:iam::YOUR_ACCOUNT_ID:oidc-provider/token.actions.githubusercontent.com"
         },
         "Action": "sts:AssumeRoleWithWebIdentity",
         "Condition": {
           "StringLike": {
             "token.actions.githubusercontent.com:sub": "repo:YOUR_ORG/YOUR_REPO:*"
           }
         }
       }
     ]
   }
   ```

3. Attach permissions:
   - `PowerUserAccess` (or custom policy with EC2, VPC, S3, Route53, IAM permissions)

4. Copy the Role ARN and add to GitHub secrets

### AWS_REGION

The AWS region where your infrastructure will be deployed. Must match the region in your `config.yaml`.

Common regions:
- `us-west-2` (Oregon)
- `us-east-1` (N. Virginia)
- `eu-west-1` (Ireland)

**Important**: AMI IDs are region-specific. If you change regions, update the `ami_id` in `config.yaml`.

### ADMIN_PASSWORD

Password for accessing the allocator web interface. Choose a strong password (12+ characters, mixed case, numbers, symbols).

This password is used to log in to the admin dashboard where you can:
- Create and destroy client VMs
- View VM status
- Assign VMs to users

### DB_PASSWORD

Password for the PostgreSQL database used by the allocator service. Choose a different strong password than `ADMIN_PASSWORD`.

This is stored securely and injected into the configuration at deployment time.

## AWS Setup Guide

### Automated Setup (Recommended)

The setup script creates all infrastructure and secrets in one go:

```bash
./scripts/setup.sh
```

This creates all required AWS resources (OIDC provider, IAM role, S3 bucket, DynamoDB table, Route53 hosted zone), sets GitHub secrets, and calls `configure.sh` to generate `config.yaml`. It is idempotent and safe to re-run.

To update configuration later (instance types, image tags, DNS/SSL options, etc.), run the config wizard directly:

```bash
./scripts/configure.sh
```

**What the script does NOT do:**
- Does NOT register domain names (you must register via Route53 registrar, CloudFlare, or other registrar)
- Does NOT create DNS records (OpenTofu handles these, or you create manually)

**After setup, your DNS/SSL approach is configured based on your wizard choices:**

1. **Route53 + Let's Encrypt**: Register domain, update nameservers to Route53
2. **CloudFlare DNS + SSL**: Manage domain/DNS in CloudFlare, create A record pointing to allocator IP
3. **IP-only** (no DNS/SSL): Access via IP address directly

---

### Manual Setup (Alternative)

If you prefer to create resources manually:

#### 1. Create S3 Bucket for OpenTofu State

```bash
# Create bucket (must be globally unique across ALL of AWS)
aws s3 mb s3://tf-state-YOUR-ORG-lablink --region us-west-2

# Enable versioning (recommended)
aws s3api put-bucket-versioning \
  --bucket tf-state-YOUR-ORG-lablink \
  --versioning-configuration Status=Enabled
```

Update `bucket_name` in `lablink-infrastructure/config/config.yaml` to match.

#### 2. Create DynamoDB Table for State Locking

```bash
aws dynamodb create-table \
  --table-name lock-table \
  --attribute-definitions AttributeName=LockID,AttributeType=S \
  --key-schema AttributeName=LockID,KeyType=HASH \
  --billing-mode PAY_PER_REQUEST \
  --region us-west-2
```

#### 3. (Optional) Allocate Elastic IP

For persistent allocator IP address across deployments:

```bash
# Allocate EIP
aws ec2 allocate-address --domain vpc --region us-west-2

# Tag it for reuse — the Name must be {deployment_name}-eip-{environment}
aws ec2 create-tags \
  --resources eipalloc-XXXXXXXX \
  --tags Key=Name,Value=my-lablink-eip-prod
```

The EIP name is derived from `deployment_name` and `environment` in `config.yaml`;
there is no separate tag field to set.

#### 4. (Optional) Set Up Route 53 for DNS

If using a custom domain:

1. Create or use existing hosted zone:
   ```bash
   aws route53 create-hosted-zone --name your-domain.com --caller-reference $(date +%s)
   ```

2. Update your domain's nameservers to point to Route 53 NS records

3. Update `dns` section in `config.yaml`:
   ```yaml
   dns:
     enabled: true
     domain: "your-domain.com"
     zone_id: "Z..." # Optional - will auto-lookup if empty
   ```

#### 5. Set Up OIDC Provider and IAM Role

See [GitHub Secrets Setup](#github-secrets-setup) above for detailed IAM role configuration.

## Deployment Workflows

### Deploy LabLink Infrastructure

Deploys or updates your LabLink infrastructure.

**Triggers**:
- Manual: Actions → "Deploy LabLink Infrastructure" → Run workflow
- Automatic: Push to `test` branch

**Inputs**:
- `deployment_name`: resource-name prefix (required, default `my-lablink`). On pushes to
  `test`, the `DEPLOYMENT_NAME` repository variable is used instead.
- `environment`: `test`, `prod`, or `ci-test` (`dev` is local-only and not exposed here)

**What it does**:
1. Configures AWS credentials via OIDC
2. Injects passwords from GitHub secrets into config
3. Runs OpenTofu to create/update infrastructure
4. Verifies deployment and DNS
5. Uploads SSH key as artifact

### Destroy LabLink Infrastructure

**⚠️ WARNING**: This destroys all infrastructure and data!

**Triggers**:
- Manual only: Actions → "Destroy LabLink Infrastructure" → Run workflow

**Inputs**:
- `confirm_destroy`: Must type "yes" to confirm
- `deployment_name`: must match the deployment you are destroying
- `environment`: `test`, `prod`, or `ci-test`

**What it does**:
1. Creates a minimal terraform backend configuration
2. Initializes OpenTofu with S3 backend to access client VM state
3. Destroys client VMs directly from the S3 state (for test/prod/ci-test)
4. Destroys the allocator infrastructure (EC2, security groups, EIP, etc.)

**Note**: Client VM state is stored in S3 (same bucket as infrastructure state). OpenTofu can destroy resources using only the state file - no terraform configuration files needed!

### Manual Cleanup and Troubleshooting

If the destroy workflow fails or leaves orphaned resources, see the **[Manual Cleanup Guide](../MANUAL_CLEANUP_GUIDE.md)** for step-by-step procedures to:

- Remove orphaned IAM roles, policies, and instance profiles
- Clean up leftover EC2 instances, security groups, and key pairs
- Fix OpenTofu state file issues (checksum mismatches, corrupted state)
- Verify complete resource removal

Common scenarios covered:
- Destroy workflow failures
- "Resource in use" errors
- Orphaned client VMs
- State lock issues

## Repository Layout

```
lablink-template/
├── .github/workflows/                  # GitHub Actions workflows
│   ├── terraform-deploy.yml            # Deploy infrastructure (OIDC → AWS)
│   ├── terraform-destroy.yml           # Destroy infrastructure + client VMs
│   ├── config-validation.yml           # Validate config.yaml on PR
│   └── startup-script-validation.yml   # Lint custom-startup.sh on PR
├── lablink-infrastructure/             # OpenTofu infrastructure
│   ├── main.tf                         # Core OpenTofu config (EC2, EIP, IAM, Route53)
│   ├── alb.tf                          # ALB resources (only when ssl.provider="acm")
│   ├── backend.tf                      # Backend configuration
│   ├── backend-*.hcl                   # Per-environment backend overrides (dev/test/prod/ci-test)
│   ├── user_data.sh                    # EC2 initialization script (templated by OpenTofu)
│   ├── config/
│   │   ├── config.yaml                 # Your active configuration
│   │   ├── *.example.yaml              # Per-flavor templates (ip-only, cloudflare, letsencrypt, acm, dev/test/prod, ci-test)
│   │   ├── custom-startup.sh           # Optional per-client-VM startup hook
│   │   └── README.md                   # Detailed config selection guide
│   └── README.md                       # Infrastructure documentation
├── scripts/                            # Helper scripts
│   ├── setup.sh                        # One-time setup: OIDC, IAM, S3, DynamoDB, GitHub secrets
│   ├── configure.sh                    # Interactive config.yaml wizard (re-runnable)
│   ├── doctor.sh                       # Pre-deploy preflight: tools, AWS, secrets, config
│   ├── init-terraform.sh               # OpenTofu init helper (reads bucket from config)
│   ├── verify-deployment.sh            # Post-deploy DNS/HTTP/SSL checks
│   ├── estimate-costs.sh               # Daily AWS cost estimate for a given config
│   ├── cleanup-orphaned-resources.sh   # Recover from failed `tofu destroy`
│   └── validate-all-configs.{sh,ps1}   # Validate every *.example.yaml against the schema
├── MANUAL_CLEANUP_GUIDE.md             # Manual cleanup procedures
├── DEPLOYMENT_CHECKLIST.md             # Pre-deployment checklist
├── README.md                           # This file
└── LICENSE
```
