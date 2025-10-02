# GitHub Actions Workflows

This directory contains CI/CD workflows for LabLink.

## Available Workflows

### 1. `lablink-images.yml` - Build Client Base Image

**Purpose**: Builds custom client base Docker image (allocator image is always maintained separately)

**When to use**:
- ✅ If you're building a custom client image with additional dependencies
- ❌ If you're using the pre-built client image `ghcr.io/talmolab/lablink-client-base-image:latest`

**To disable** (if using pre-built client image):
1. Rename file to `lablink-images.yml.disabled`, OR
2. Delete the file, OR
3. Comment out the `on:` triggers

**Note**: This workflow only builds the client image. The allocator image (`ghcr.io/talmolab/lablink-allocator-image:latest`) is maintained in the main LabLink repository.

### 2. `lablink-allocator-terraform.yml` - Deploy Infrastructure

**Purpose**: Deploys the LabLink allocator EC2 instance using Terraform

**When to use**:
- ✅ Always (for infrastructure deployment)

**Requirements**:
- GitHub secret: `AWS_ROLE_ARN` configured
- Terraform backend configured (S3 or local)

### 3. `lablink-allocator-destroy.yml` - Destroy Infrastructure

**Purpose**: Tears down the LabLink infrastructure

**When to use**:
- When cleaning up environments
- When testing deployments

**⚠️ Warning**: This will destroy all VMs and data!

### 4. `client-vm-infrastructure-test.yml` - Test Client VM Creation

**Purpose**: Tests that client VMs can be provisioned correctly

**When to use**:
- For testing infrastructure changes
- For CI/CD validation

## Quick Start

### Option A: Using Pre-Built Images (Recommended)

The allocator image is always pre-built. For the client image:

1. **Disable client image builds** (if using pre-built):
   ```bash
   mv .github/workflows/lablink-images.yml .github/workflows/lablink-images.yml.disabled
   ```

2. **Use maintained images** in `config.yaml`:
   ```yaml
   machine:
     image: "ghcr.io/talmolab/lablink-client-base-image:latest"
   ```

3. **Configure AWS secrets**:
   - Go to Settings → Secrets → Actions
   - Add `AWS_ROLE_ARN`

3. **Deploy infrastructure**:
   - Go to Actions → "Terraform Deploy"
   - Run workflow → Select environment
   - Wait for deployment to complete

### Option B: Building Custom Client Image

1. **Keep `lablink-images.yml` enabled**

2. **Modify client Dockerfile**:
   ```bash
   # Edit lablink-client-base/lablink-client-base-image/Dockerfile
   # Add your custom dependencies
   ```

3. **Update image reference** in:
   - `lablink-allocator-service/conf/config.yaml`:
     ```yaml
     machine:
       image: "ghcr.io/YOUR_ORG/lablink-client-base-image:latest"
     ```

4. **Push changes** to trigger client image build:
   ```bash
   git add .
   git commit -m "Customize Docker images"
   git push
   ```

5. **Wait for client image to build**, then deploy infrastructure

## Workflow Triggers

| Workflow | Manual | Push (main) | Push (test) | Pull Request |
|----------|--------|-------------|-------------|--------------|
| lablink-images.yml | ✅ | ✅ | ✅ | ✅ |
| lablink-allocator-terraform.yml | ✅ | ❌ | ✅ | ❌ |
| lablink-allocator-destroy.yml | ✅ | ❌ | ❌ | ❌ |
| client-vm-infrastructure-test.yml | ✅ | ❌ | ❌ | ❌ |

## Troubleshooting

### Image Build Failing

**Check**:
- Dockerfiles are valid
- Base images are accessible
- GitHub Container Registry permissions are correct

### Terraform Deployment Failing

**Check**:
- `AWS_ROLE_ARN` secret is set correctly
- IAM role has required permissions
- Terraform state backend is configured
- `config.yaml` and `terraform.tfvars` are properly configured

### "No config.yaml found" Error

**Solution**:
- The template only includes `config.yaml.example`
- Copy it to `config.yaml` and commit:
  ```bash
  cd lablink-allocator/lablink-allocator-service/conf
  cp config.yaml.example config.yaml
  # Edit config.yaml with your settings
  git add config.yaml
  git commit -m "Add configuration"
  ```

## See Also

- [USE_CASES.md](../../USE_CASES.md) - When to build custom images
- [TEMPLATE_SETUP.md](../../TEMPLATE_SETUP.md) - Complete setup guide
- [Main README](../../README.md) - Overview and quick start
