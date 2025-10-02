# LabLink Template Setup Guide

This guide will walk you through setting up your own LabLink deployment from this template.

## Table of Contents

- [Overview](#overview)
- [Prerequisites](#prerequisites)
- [Initial Setup](#initial-setup)
- [Configuration](#configuration)
- [AWS Setup](#aws-setup)
- [GitHub Setup](#github-setup)
- [Deployment](#deployment)
- [Troubleshooting](#troubleshooting)

## Overview

LabLink consists of two main components:

1. **Allocator Service** - Manages VM allocation, runs on a single EC2 instance with PostgreSQL
2. **Client VMs** - Ephemeral compute instances that run user workloads in Docker containers

## Prerequisites

### Required

- **AWS Account** with permissions to create:
  - EC2 instances
  - Security Groups
  - Key Pairs
  - (Optional) Route 53 hosted zones for DNS
  - (Optional) S3 buckets for Terraform state

- **GitHub Account** with permissions to:
  - Create repositories from templates
  - Configure GitHub Actions
  - Access GitHub Container Registry (GHCR)

### Recommended Tools

- Docker Desktop (for local testing)
- AWS CLI v2
- Terraform 1.4.6+
- Python 3.9+ with `uv` package manager

## Initial Setup

### 1. Create Repository from Template

1. Click "Use this template" on the [lablink-template](https://github.com/YOUR_ORG/lablink-template) repository
2. Choose your organization and repository name
3. Clone your new repository:

```bash
git clone https://github.com/YOUR_ORG/YOUR_REPO.git
cd YOUR_REPO
```

### 2. Copy Example Configuration Files

```bash
# Allocator service configuration
cd lablink-allocator/lablink-allocator-service
cp conf/config.yaml.example conf/config.yaml
cp .env.example .env

# Terraform variables
cd ../
cp terraform.tfvars.example terraform.tfvars
```

## Configuration

### Configure `config.yaml`

Edit `lablink-allocator/lablink-allocator-service/conf/config.yaml`:

```yaml
# Database - keep defaults or customize
db:
  dbname: "lablink_db"
  user: "lablink"
  password: "CHANGE_ME_TO_SECURE_PASSWORD"  # ⚠️ REQUIRED
  host: "localhost"
  port: 5432

# Machine/VM configuration
machine:
  machine_type: "g4dn.xlarge"  # AWS instance type
  image: "ghcr.io/YOUR_ORG/YOUR_CLIENT_IMAGE:latest"  # ⚠️ REQUIRED - Your Docker image
  ami_id: "ami-067cc81f948e50e06"  # Ubuntu 20.04 with GPU support (update for your region)
  repository: "https://github.com/YOUR_ORG/YOUR_DATA_REPO.git"  # Optional: git repo to clone
  software: "your-software"  # ⚠️ REQUIRED - Your software name
  extension: "ext"  # ⚠️ REQUIRED - Your data file extension

# Application
app:
  admin_user: "admin"
  admin_password: "CHANGE_ME_TO_SECURE_PASSWORD"  # ⚠️ REQUIRED
  region: "us-west-2"  # ⚠️ Update to your AWS region

# DNS (optional but recommended for production)
dns:
  enabled: false  # Set to true if using custom domain
  domain: ""  # e.g., "example.com"
  app_name: "lablink"
  pattern: "auto"  # auto, app-only, or custom
```

### Configure `.env`

Edit `lablink-allocator/lablink-allocator-service/.env`:

```bash
# AWS Credentials (for local development/testing)
AWS_ACCESS_KEY_ID=your_access_key_here
AWS_SECRET_ACCESS_KEY=your_secret_key_here
AWS_DEFAULT_REGION=us-west-2

# Database
DATABASE_URL=postgresql://lablink:YOUR_PASSWORD@localhost:5432/lablink_db

# Flask
FLASK_ENV=development
SECRET_KEY=generate_random_secret_here
```

### Configure Terraform Variables

Edit `lablink-allocator/terraform.tfvars`:

```hcl
# DNS configuration
dns_name = ""  # Leave empty to disable DNS, or set to "example.com"
```

## AWS Setup

### 1. Create IAM User or Role

For **GitHub Actions** deployment (recommended):

1. Create an IAM role with permissions:
   - EC2 full access
   - Route53 (if using DNS)
   - S3 (if using remote state)

2. Configure OIDC for GitHub Actions:
   - Follow [AWS OIDC guide](https://docs.github.com/en/actions/deployment/security-hardening-your-deployments/configuring-openid-connect-in-amazon-web-services)
   - Note the Role ARN for GitHub secrets

For **local deployment**:

1. Create IAM user with same permissions
2. Generate access keys
3. Configure AWS CLI: `aws configure`

### 2. (Optional) Set up S3 Backend for Terraform State

```bash
# Create S3 bucket for Terraform state
aws s3 mb s3://YOUR_ORG-lablink-terraform-state --region us-west-2

# Create DynamoDB table for state locking
aws dynamodb create-table \
  --table-name YOUR_ORG-lablink-terraform-locks \
  --attribute-definitions AttributeName=LockID,AttributeType=S \
  --key-schema AttributeName=LockID,KeyType=HASH \
  --billing-mode PAY_PER_REQUEST \
  --region us-west-2
```

Update `lablink-allocator/backend-prod.hcl`:

```hcl
bucket         = "YOUR_ORG-lablink-terraform-state"
key            = "lablink/allocator/terraform.tfstate"
region         = "us-west-2"
dynamodb_table = "YOUR_ORG-lablink-terraform-locks"
```

### 3. (Optional) Configure DNS

If using a custom domain:

1. Purchase domain or use existing one
2. Create Route 53 hosted zone (or use existing)
3. Update NS records at your registrar
4. Set `dns.enabled: true` in `config.yaml`
5. Set `dns.domain: "your-domain.com"` in `config.yaml`

## GitHub Setup

### 1. Enable GitHub Container Registry

GHCR is automatically available. To authenticate locally:

```bash
echo $GITHUB_TOKEN | docker login ghcr.io -u YOUR_USERNAME --password-stdin
```

### 2. Configure Repository Secrets

Go to your repository → Settings → Secrets and variables → Actions

Add these secrets:

| Secret Name | Description | Example Value |
|------------|-------------|---------------|
| `AWS_ROLE_ARN` | IAM role ARN for OIDC | `arn:aws:iam::123456789:role/github-actions` |

> Note: `GITHUB_TOKEN` is automatically provided by GitHub Actions

### 3. Configure Repository Permissions

Settings → Actions → General → Workflow permissions:
- ✅ Read and write permissions
- ✅ Allow GitHub Actions to create and approve pull requests

## Deployment

### Option 1: Deploy via GitHub Actions (Recommended)

1. **Push to trigger image builds:**

```bash
git add .
git commit -m "Configure LabLink deployment"
git push origin main
```

This triggers:
- `.github/workflows/lablink-images.yml` - Builds and pushes Docker images

2. **Manually trigger infrastructure deployment:**

- Go to Actions → "Terraform Deploy"
- Click "Run workflow"
- Select environment: `dev`, `test`, or `prod`
- Click "Run workflow"

3. **Access your deployment:**

Check the workflow output for:
- EC2 Public IP
- FQDN (if DNS configured)
- SSH key (downloaded as artifact)

### Option 2: Deploy Locally

1. **Build images locally:**

```bash
# Allocator image
docker build -t lablink-allocator -f lablink-allocator/Dockerfile .

# Client base image
docker build -t lablink-client-base lablink-client-base/lablink-client-base-image/
```

2. **Deploy with Terraform:**

```bash
cd lablink-allocator

# Initialize Terraform
terraform init

# Review plan
terraform plan -var="resource_suffix=dev"

# Apply
terraform apply -var="resource_suffix=dev"
```

3. **Get connection info:**

```bash
# Get public IP
terraform output ec2_public_ip

# Get SSH key
terraform output -raw private_key_pem > lablink-key.pem
chmod 600 lablink-key.pem

# SSH into instance
ssh -i lablink-key.pem ubuntu@$(terraform output -raw ec2_public_ip)
```

## Post-Deployment

### Verify Service is Running

```bash
# SSH into allocator
ssh -i lablink-key.pem ubuntu@<PUBLIC_IP>

# Check Docker container
sudo docker ps

# Check logs
sudo docker logs <container_id>

# Check Flask is responding
curl http://localhost:5000
```

### Access Web Interface

Navigate to:
- With DNS: `https://lablink.your-domain.com`
- Without DNS: `http://<PUBLIC_IP>:5000`

## Customization

### Update Docker Images

1. Modify `lablink-allocator/Dockerfile` or `lablink-client-base/lablink-client-base-image/Dockerfile`
2. Push changes to trigger rebuild:

```bash
git add .
git commit -m "Update Docker images"
git push
```

Images are automatically built and pushed to GHCR.

### Update Client VM Configuration

Edit `lablink-allocator/lablink-allocator-service/conf/config.yaml`:

- Change instance types: `machine.machine_type`
- Change AMI: `machine.ami_id` (ensure it matches your region)
- Update Docker image: `machine.image`

### Add Custom Code

The template provides infrastructure. To add your application code:

1. Add Python code to `lablink-allocator/lablink-allocator-service/`
2. Add Flask routes, database models, etc.
3. Update `pyproject.toml` with dependencies
4. Rebuild images

## Troubleshooting

### Build Failures

**Problem**: Docker image build fails

**Solution**:
- Check Dockerfile syntax
- Verify base images are accessible
- Check GitHub Actions logs for specific errors

### Terraform Errors

**Problem**: `terraform apply` fails with permission errors

**Solution**:
- Verify AWS credentials/role has required permissions
- Check AWS service limits
- Ensure region in config matches Terraform region

**Problem**: Terraform state locked

**Solution**:
```bash
terraform force-unlock <LOCK_ID>
```

### DNS Issues

**Problem**: DNS not resolving

**Solution**:
- Verify Route 53 hosted zone NS records match registrar
- Wait for DNS propagation (up to 48 hours)
- Check `terraform output allocator_fqdn`
- Test with `nslookup lablink.your-domain.com`

### Connection Issues

**Problem**: Cannot access allocator web interface

**Solution**:
- Check security group allows inbound traffic on port 5000
- Verify EC2 instance is running: `aws ec2 describe-instances`
- Check Docker container is running: `docker ps`
- Check logs: `docker logs <container>`

### Database Issues

**Problem**: Database connection errors

**Solution**:
- Verify PostgreSQL is running: `sudo service postgresql status`
- Check database credentials in config.yaml
- Verify `init.sql` was executed
- Restart container: `docker restart <container>`

## Additional Resources

- [AWS EC2 Documentation](https://docs.aws.amazon.com/ec2/)
- [Terraform AWS Provider](https://registry.terraform.io/providers/hashicorp/aws/latest/docs)
- [GitHub Actions Documentation](https://docs.github.com/en/actions)
- [Docker Documentation](https://docs.docker.com/)

## Getting Help

- Review the [main README](README.md)
- Check component READMEs:
  - [Allocator](lablink-allocator/README.md)
  - [Client Base](lablink-client-base/lablink-client-base-image/README.md)
- Open an issue on your repository for help

## Security Best Practices

1. **Never commit secrets** - Use `.env` and `.gitignore`
2. **Rotate credentials** - Regularly update passwords and keys
3. **Use OIDC** - Prefer OIDC over static AWS credentials for GitHub Actions
4. **Enable HTTPS** - Use DNS + SSL certificates in production
5. **Restrict security groups** - Only open required ports
6. **Monitor costs** - Set up AWS billing alerts
7. **Review IAM permissions** - Follow principle of least privilege
