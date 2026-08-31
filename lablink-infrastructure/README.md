# LabLink Infrastructure

Deploy your own LabLink VM allocation system for computational research workflows.

## Quick Start

### Step 0: GitHub Secrets Setup (Required for GitHub Actions)

If you plan to deploy via GitHub Actions workflows, you must configure one repository secret:

1. **Go to your repository Settings** → Secrets and variables → Actions
2. **Click "New repository secret"**
3. **Add the following secret:**

   | Name           | Value                                              | Description                          |
   | -------------- | -------------------------------------------------- | ------------------------------------ |
   | `AWS_ROLE_ARN` | `arn:aws:iam::YOUR-ACCOUNT-ID:role/YOUR-ROLE-NAME` | IAM role ARN for OIDC authentication |

**How to create the AWS IAM role for OIDC:**

```bash
# 1. Create a trust policy file
cat > trust-policy.json <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Federated": "arn:aws:iam::YOUR-ACCOUNT-ID:oidc-provider/token.actions.githubusercontent.com"
      },
      "Action": "sts:AssumeRoleWithWebIdentity",
      "Condition": {
        "StringEquals": {
          "token.actions.githubusercontent.com:aud": "sts.amazonaws.com"
        },
        "StringLike": {
          "token.actions.githubusercontent.com:sub": "repo:YOUR-ORG/YOUR-REPO:*"
        }
      }
    }
  ]
}
EOF

# 2. Create the IAM role
aws iam create-role \
  --role-name github-actions-lablink-deploy \
  --assume-role-policy-document file://trust-policy.json

# 3. Attach required policies
aws iam attach-role-policy \
  --role-name github-actions-lablink-deploy \
  --policy-arn arn:aws:iam::aws:policy/PowerUserAccess

# 4. Get the role ARN (use this for AWS_ROLE_ARN secret)
aws iam get-role \
  --role-name github-actions-lablink-deploy \
  --query 'Role.Arn' \
  --output text
```

**Note:** If deploying locally with OpenTofu (not via GitHub Actions), you don't need this secret. Just configure AWS CLI credentials instead.

### Prerequisites

- AWS account with credentials configured
- OpenTofu installed (v1.12.5 pinned in CI) for local deployments
- Docker images available on GHCR (or use public LabLink images)
- GitHub repository secret `AWS_ROLE_ARN` configured (for GitHub Actions deployments)

### 1. Configure

```bash
# Copy example configuration
cp config/example.config.yaml config/config.yaml
```

**Edit `config/config.yaml`:**

- **REQUIRED**: Change `db.password` and `app.admin_password` (security!)
- **REQUIRED**: Set `bucket_name` to a globally unique S3 bucket name (for test/prod)
- Set `machine.ami_id` to the client AMI for your AWS region (see [Deploying to another region](#deploying-to-another-region))
- Customize `machine.image` to use your Docker image or LabLink's public images
- Customize `machine.repository` to clone your research code
- Set `app.region` to your AWS region — this drives the OpenTofu provider, the S3 backend, and client VM provisioning

**Example configuration:**

```yaml
db:
  password: "YOUR-SECURE-DB-PASSWORD" # CHANGE THIS!

machine:
  machine_type: "g4dn.xlarge"
  image: "ghcr.io/talmolab/lablink-client-base-image:latest"
  ami_id: "ami-0601752c11b394251" # Ubuntu 24.04 with Docker + Nvidia (us-west-2)
  repository: "https://github.com/talmolab/sleap-tutorial-data.git"
  software: "sleap"

app:
  admin_password: "YOUR-SECURE-ADMIN-PASSWORD" # CHANGE THIS!
  region: "us-west-2"

bucket_name: "tf-state-lablink-yourname" # Must be globally unique

dns:
  enabled: true
  terraform_managed: true
  domain: "lablink.yourdomain.com"
  zone_id: "Z..." # Your Route 53 hosted zone ID

ssl:
  provider: "letsencrypt" # or "cloudflare" or "none"
  email: "admin@yourdomain.com"
```

### 2. Deploy Infrastructure

> **Upgrading from Terraform?** If you have run `terraform init` in this
> directory before, a `.terraform.lock.hcl` is left behind pinning providers to
> `registry.terraform.io`. OpenTofu honours that file silently and keeps pulling
> HashiCorp-hosted providers. Run `tofu init -upgrade`, or delete
> `.terraform.lock.hcl` and re-init, to move to `registry.opentofu.org`.
>
> This affects local working directories and the `lablink` CLI's
> `~/.lablink/cache/terraform/` only. CI is unaffected — runners start clean.

**Option A: Using helper script (recommended for first-time setup)**

```bash
# Initialize OpenTofu with automatic bucket configuration
../scripts/init-terraform.sh dev   # S3 backend, reads bucket from config.yaml
../scripts/init-terraform.sh test  # S3 backend, reads bucket from config.yaml
../scripts/init-terraform.sh prod  # S3 backend, reads bucket from config.yaml

# Review changes
tofu plan

# Deploy
tofu apply
```

**Option B: Manual OpenTofu commands**

```bash
# Every environment uses the S3 backend; the .hcl only sets the state key
tofu init -backend-config=backend-dev.hcl -backend-config="bucket=YOUR-BUCKET-NAME"
tofu init -backend-config=backend-test.hcl -backend-config="bucket=YOUR-BUCKET-NAME"

# Review and apply
tofu plan
tofu apply
```

### 3. Verify Deployment (Optional)

After deployment completes, you can verify everything is working:

```bash
# Config-aware mode (recommended) — auto-reads config.yaml + tofu outputs
../scripts/verify-deployment.sh dev

# Or with explicit domain and IP (backwards-compatible)
DOMAIN=$(tofu output -raw allocator_fqdn)
IP=$(tofu output -raw ec2_public_ip)
../scripts/verify-deployment.sh "$DOMAIN" "$IP"
```

The verification script checks:

- DNS resolution (if domain configured)
- HTTP connectivity
- HTTPS/SSL certificate (if Let's Encrypt enabled)

### 4. Access Your Allocator

**With DNS configured:**

```
Allocator: https://lablink.yourdomain.com
Admin UI:  https://lablink.yourdomain.com/admin
```

**Without DNS (IP-only):**

```
Allocator: http://<ec2-public-ip>:5000
Admin UI:  http://<ec2-public-ip>:5000/admin
```

## What This Deploys

- **Allocator EC2 Instance**: Runs LabLink allocator service (Flask app + PostgreSQL in Docker)
- **Caddy Server**: Automatic HTTPS with Let's Encrypt SSL certificates
- **Route 53 DNS**: Automatic DNS record management (if configured)
- **Security Groups**: Network security rules
- **IAM Roles**:
  - **Allocator Instance Role**: A role for the allocator EC2 instance with permissions to manage the lifecycle of client VMs (run, terminate, tag, etc.) and their associated resources (IAM roles, instance profiles).

## Environments

LabLink supports three deployment environments:

| Environment | Backend State | Use Case                        | S3 Bucket Required? |
| ----------- | ------------- | ------------------------------- | ------------------- |
| `dev`       | S3            | Local testing, experimentation  | Yes                 |
| `test`      | S3            | Staging, pre-production testing | Yes                 |
| `prod`      | S3            | Production deployments          | Yes                 |

Each environment maintains separate OpenTofu state to avoid conflicts.

## Configuration Reference

### Database (`db`)

- `password`: PostgreSQL password (**CHANGE THIS!**) — the only configurable
  database setting. Postgres runs inside the allocator container with a fixed
  identity (`lablink_db`/`lablink` on `localhost:5432`).

### Machine Settings (`machine`)

- `machine_type`: AWS EC2 instance type for client VMs (e.g., `g4dn.xlarge`, `g5.2xlarge`)
- `image`: Docker image for client container (e.g., `ghcr.io/talmolab/lablink-client-base-image:latest`)
- `ami_id`: Amazon Machine Image for client VMs (region-specific)
- `repository`: Git repository to clone on client VMs (optional)
- `software`: Software identifier (e.g., `sleap`)

### Application (`app`)

- `admin_password`: Admin UI password (**CHANGE THIS!**)
- `admin_user`: Admin username (default: `admin`)
- `region`: AWS region (e.g., `us-west-2`)

### DNS Configuration (`dns`)

- `enabled`: Enable DNS management (true/false)
- `terraform_managed`: Let OpenTofu manage Route 53 records (true/false)
- `domain`: Your domain name (e.g., `lablink.example.com`)
- `zone_id`: Route 53 hosted zone ID (required if `terraform_managed: true`)

### SSL Configuration (`ssl`)

- `provider`: SSL provider (`letsencrypt`, `cloudflare`, `acm`, or `none`)
- `email`: Email for Let's Encrypt notifications
- `certificate_arn`: Required when `provider="acm"` - ARN of ACM certificate

**SSL Provider Options:**

- `letsencrypt`: Caddy automatically obtains trusted Let's Encrypt certificates and serves HTTPS
- `cloudflare`: CloudFlare proxy provides edge SSL. Caddy serves the origin over HTTPS with a self-signed cert (`tls internal`), compatible with CloudFlare's recommended **Full** mode (Full does not validate the origin cert). Also serves HTTP for Flexible mode. Use Full, not Full (strict).
- `acm`: AWS Certificate Manager via Application Load Balancer (enterprise-grade SSL)
- `none`: HTTP only (no SSL) - for testing purposes only

**Note:** Let's Encrypt always uses production certificates (no staging mode). Rate limit is 50 certificates per registered domain per week.

### OpenTofu State (`bucket_name`)

- S3 bucket name for OpenTofu state storage (test/prod only)
- Must be globally unique

### Startup Script (`startup_script`)

- `enabled`: `true` to run the custom startup script on client VMs, `false` to disable.
- `path`: Path to the custom startup script file. Default: `config/custom-startup.sh`.
- `on_error`: Behavior on script error. `continue` (default) ignores errors, `fail` stops VM setup.

**Additional Resources:**

- [Configuration guide](config/README.md) - Every config field, the config flavors, validation
- [Troubleshooting](../docs/TROUBLESHOOTING.md) - Failed deploys, DNS, SSL, state locks
- [LabLink documentation](https://talmolab.github.io/lablink/) - Allocator and client internals

## Included Scripts

### `init-terraform.sh` (Optional Helper)

Simplifies OpenTofu initialization by automatically reading the S3 bucket name from your config file.

**Usage:**

```bash
../scripts/init-terraform.sh [dev|test|prod|ci-test]
```

**What it does:**

- Reads `bucket_name` from `config/config.yaml`
- Runs `tofu init` with appropriate backend configuration
- Validates configuration before initializing

**Equivalent manual command:**

```bash
tofu init -backend-config=backend-test.hcl -backend-config="bucket=YOUR-BUCKET"
```

### `verify-deployment.sh` (Optional Manual Verification)

Comprehensive deployment verification script for post-deployment testing.

**Usage:**

```bash
# Config-aware mode (recommended): reads config.yaml + OpenTofu outputs automatically
../scripts/verify-deployment.sh <environment>
../scripts/verify-deployment.sh --ci <environment>

# Backwards-compatible mode: explicit domain and IP
../scripts/verify-deployment.sh <domain> <ip>
../scripts/verify-deployment.sh --ci <domain> <ip>

# Examples:
../scripts/verify-deployment.sh prod                                        # Config-aware
../scripts/verify-deployment.sh --ci ci-test                                # Config-aware in CI
../scripts/verify-deployment.sh test.lablink.sleap.ai 52.10.119.234         # Legacy mode
../scripts/verify-deployment.sh "" 52.10.119.234                            # IP-only (legacy)
```

**What it checks:**

1. DNS resolution (waits up to 5 minutes for propagation)
2. HTTP connectivity (waits for allocator to start)
3. HTTPS/SSL certificate (waits for Let's Encrypt, if enabled)

**When to use:**

- After first deployment to verify everything works
- When troubleshooting DNS or SSL issues
- To confirm HTTPS certificate was obtained

**Note:** GitHub Actions workflows include automatic verification, so this script is mainly for local deployments or manual troubleshooting.

### `config/custom-startup.sh` (Customizable Client Startup)

The `config/custom-startup.sh` script is a customizable script that is executed upon the startup of a client VM. This script provides a way to automate the setup and configuration of the client environment.

**Customization:**
You can add custom startup behavior by modifying the `config/custom-startup.sh` script. For example, you could:

- Install additional software packages.
- Start additional services.

Any changes made to this script will be reflected in the client VMs upon their next startup.

### `user_data.sh` (Automatic - DO NOT RUN MANUALLY)

EC2 instance initialization script embedded in OpenTofu configuration.

**What it does:**

- Installs Docker and Caddy on the allocator EC2 instance
- Pulls the allocator Docker image
- Starts the allocator container
- Configures Caddy for SSL termination

**Note:** This script runs automatically when the EC2 instance boots. You never need to run it manually.

## AWS Region Configuration

AMI IDs are region-specific. If deploying to a different region:

1. Update `app.region` in `config/config.yaml`
2. Find the appropriate AMI for your region:
   ```bash
   # Ubuntu 24.04 with Docker + Nvidia GPU drivers
   aws ec2 describe-images \
     --region YOUR-REGION \
     --owners 099720109477 \
     --filters "Name=name,Values=ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*" \
     --query 'Images | sort_by(@, &CreationDate) | [-1].[ImageId,Name]'
   ```
3. Update `machine.ami_id` in `config/config.yaml`

**Pre-configured custom AMIs.** AMI IDs are region-scoped, so each image has a different
ID per region. The client AMI goes in `config.yaml`; the allocator AMI is looked up by
region in `main.tf` and needs no configuration.

| Region | Client AMI (`machine.ami_id`) | Allocator AMI (`local.allocator_ami_by_region`) |
|--------|-------------------------------|--------------------------------------------------|
| `us-west-2` | `ami-0601752c11b394251` | `ami-0bd08c9d4aa9f0bc6` |
| `us-east-1` | `ami-0c3412413810adacc` | `ami-0731df69b0f192475` |
| `us-east-2` | `ami-0cd7567480c4840a0` | `ami-0662274c85c271f53` |

Both are Ubuntu 24.04; the client image adds Docker and the NVIDIA GPU drivers, the
allocator image adds Docker.

### Deploying to another region

`app.region` in `config.yaml` is what decides where the deployment lands — the AWS
provider reads it, `scripts/init-terraform.sh` points the S3 backend at it, and the
allocator uses it to provision client VMs. Set it to one of the regions above and set
`machine.ami_id` to that region's client AMI. A region with no entry in
`local.allocator_ami_by_region` makes OpenTofu **refuse to plan**, listing the supported
ones, rather than creating half a deployment and dying on `InvalidAMIID.NotFound`.

Adding a region means copying both images into it, because AMI IDs do not cross regions:

```bash
aws ec2 copy-image --source-region us-west-2 \
  --source-image-id ami-0bd08c9d4aa9f0bc6 \
  --region YOUR-REGION --name lablink-allocator-ubuntu24-docker

aws ec2 copy-image --source-region us-west-2 \
  --source-image-id ami-0601752c11b394251 \
  --region YOUR-REGION --name lablink-client-ubuntu24-docker-nvidia
```

Then make **both copies public** — labs launch these from their own AWS accounts, so a
private copy is useless to them — add the allocator ID to `local.allocator_ami_by_region`
in `main.tf`, and point `machine.ami_id` at the client copy. Note that "block public
access for AMIs" is enabled by default in newer AWS accounts and must be lifted per
region (`aws ec2 disable-image-block-public-access --region YOUR-REGION`) before a copy
can be published.

Both images are custom builds with Docker pre-installed, which `user_data.sh` depends on
— it starts the Docker daemon rather than installing it, so a stock Ubuntu AMI boots and
then fails. There is no `config.yaml` field for the allocator AMI because `config.yaml`
is validated against the allocator's schema, which has none: any extra key makes the
config fail outright.

## Using Custom Docker Images

### Option 1: Use LabLink Public Images

```yaml
machine:
  image: "ghcr.io/talmolab/lablink-client-base-image:latest"
```

**Available tags:**

- `latest` - Latest stable release
- `linux-amd64-test` - Latest development build
- `0.0.8a0` - Specific version tag

### Option 2: Build Your Own Images

1. Fork the [LabLink repository](https://github.com/talmolab/lablink)
2. Customize the client package in `packages/client/`
3. Build and publish your images via GitHub Actions
4. Update `machine.image` in your config to use your custom image

## GitHub Actions Deployment

This infrastructure can be deployed via GitHub Actions workflows:

- **Deploy**: `.github/workflows/terraform-deploy.yml`
- **Destroy**: `.github/workflows/terraform-destroy.yml`

Both workflows authenticate to AWS using OIDC (no long-lived AWS keys in GitHub secrets) — see the [setup reference's OIDC section](../docs/SETUP.md#why-oidc-instead-of-long-lived-aws-keys) for how the role-assume flow works.

See the workflows in the `.github` directory for automated deployment examples.

## Security Best Practices

- ✅ **Secure the Allocator Instance**: The allocator EC2 instance has a powerful IAM role that allows it to create, terminate, and manage other EC2 instances. Unauthorized access to this instance could lead to misuse of AWS resources. Ensure that its security group is restricted to trusted IP addresses and that you follow all other security best practices to protect it.
- ✅ **Change default passwords** in `config.yaml` before deploying
- ✅ Use **IAM roles** instead of access keys when possible
- ✅ Enable **S3 backend encryption** for production state files
- ✅ **Restrict security group** ingress rules to trusted IPs
- ✅ **Rotate SSH keys** regularly (every 90 days recommended)
- ✅ Use **separate environments** (dev/test/prod) with different credentials
- ✅ Enable **MFA** on AWS accounts with production access

## Troubleshooting

### Common Issues

**DNS not resolving:**

- Check Route 53 hosted zone exists and `zone_id` is correct
- Wait up to 5 minutes for DNS propagation
- Verify domain registrar nameservers point to Route 53

**SSL certificate not obtained:**

- Check DNS resolves correctly first (SSL requires valid DNS)
- Verify port 80 and 443 are accessible (Let's Encrypt validation)
- Check Caddy logs: `ssh ubuntu@<ip> sudo journalctl -u caddy -f`

**Allocator not responding:**

- Check Docker container is running: `ssh ubuntu@<ip> sudo docker ps`
- View container logs: `ssh ubuntu@<ip> sudo docker logs $(sudo docker ps -q)`
- Verify security group allows inbound traffic on port 5000

**OpenTofu state locked:**

- Check DynamoDB lock table in AWS console
- Manually remove lock if workflow was interrupted
- Use `tofu force-unlock <lock-id>` as last resort

### Running Scripts Locally

If you want to run the verification or other scripts locally (outside of CI), follow these steps:

**Prerequisites:**

```bash
# 1. Navigate to the infrastructure directory
cd lablink-infrastructure

# 2. Ensure config/config.yaml exists
cp config/example.config.yaml config/config.yaml  # if not already created

# 3. Initialize OpenTofu for your environment
../scripts/init-terraform.sh dev    # state at s3://<bucket>/dev/terraform.tfstate
../scripts/init-terraform.sh test   # state at s3://<bucket>/test/terraform.tfstate

# 4. Deploy (or have an existing deployment)
tofu apply -var="deployment_name=YOUR-DEPLOYMENT" -var="environment=dev"
```

**Running verification:**

```bash
# From lablink-infrastructure/
../scripts/verify-deployment.sh dev
```

**Common errors:**

| Error                                                 | Cause                                             | Fix                                                                |
| ----------------------------------------------------- | ------------------------------------------------- | ------------------------------------------------------------------ |
| `Cannot find config/config.yaml`                      | Script not run from correct directory             | `cd lablink-infrastructure` first, or run from repo root           |
| `Could not read ec2_public_ip from OpenTofu outputs` | OpenTofu not initialized or no deployment exists | Run `../scripts/init-terraform.sh <env>` then `tofu apply`    |
| `nslookup: command not found`                         | Missing DNS tools                                 | Install `dnsutils` (Ubuntu) or `bind` (macOS: `brew install bind`) |

### Getting Help

- **Documentation**: https://talmolab.github.io/lablink/
- **Issues**: https://github.com/talmolab/lablink/issues
- **Troubleshooting Guide**: https://talmolab.github.io/lablink/troubleshooting/

## Cleanup

### Normal Destroy

To destroy all infrastructure:

```bash
tofu destroy
```

This removes:

- Allocator EC2 instance
- Elastic IP (if `eip.strategy = "dynamic"` — persistent EIPs are preserved)
- Application Load Balancer (if `ssl.provider = "acm"`)
- Security groups
- Route 53 DNS records (if `dns.terraform_managed = true`)
- IAM roles, policies, and instance profile for the allocator

**Note:** The S3 bucket for OpenTofu state is NOT deleted automatically. Delete it manually if no longer needed.

### Cleanup Orphaned Resources

If `tofu destroy` fails or leaves orphaned resources, use the automated cleanup script:

```bash
# From repository root
./scripts/cleanup-orphaned-resources.sh <environment>

# Example:
./scripts/cleanup-orphaned-resources.sh test
```

The script automatically handles:

- Reading `deployment_name`, `bucket_name`, `region` and `eip.strategy` from `config/config.yaml`
- Backing up OpenTofu state files before deletion
- Deleting resources in correct dependency order — instances and the load balancer before the security groups holding their ENIs
- Skipping the Elastic IP unless `eip.strategy` is `dynamic`, so a persistent EIP is never released
- Dry-run mode for safe testing: `./scripts/cleanup-orphaned-resources.sh test --dry-run`

Every allocator-side resource is named `{deployment_name}-{resource}-{environment}`, so
the script needs the right `deployment_name`. It reads one from `config.yaml`, but the
deploy workflow pins its own from the workflow input without writing it back — so
recovering a CI deploy usually needs the override:

```bash
./scripts/cleanup-orphaned-resources.sh test --deployment-name sleap-lablink --dry-run
```

A run that reports `0 deleted` with a long list of `not found` is almost always a
`deployment_name` mismatch, not a clean environment.

For detailed manual cleanup procedures and troubleshooting, see [MANUAL_CLEANUP_GUIDE.md](../docs/MANUAL_CLEANUP_GUIDE.md).

## Documentation

Full documentation available at: https://talmolab.github.io/lablink/

- [Quickstart Guide](https://talmolab.github.io/lablink/quickstart/)
- [Configuration Reference](https://talmolab.github.io/lablink/configuration/)
- [Architecture Overview](https://talmolab.github.io/lablink/architecture/)
- [Deployment Guide](https://talmolab.github.io/lablink/deployment/)
- [DNS Configuration](https://talmolab.github.io/lablink/dns-configuration/)
- [Troubleshooting](https://talmolab.github.io/lablink/troubleshooting/)

## Contributing

Issues and contributions welcome at [talmolab/lablink](https://github.com/talmolab/lablink)

See [CONTRIBUTING.md](https://github.com/talmolab/lablink/blob/main/docs/contributing.md) for development guidelines.

## License

BSD-3-Clause License - see [LICENSE](../LICENSE) file
