# LabLink Template

> **This is a template repository.** Click "Use this template" to create your own LabLink deployment.

Dynamic VM allocation and management system for computational research workflows.

## Overview

LabLink automates deployment and management of cloud-based VMs for running research software. It provides a web interface for requesting VMs, tracking their status, and managing computational workloads.

This template provides a complete starting point for deploying your own LabLink infrastructure.

**Note**: The Docker images and Python packages are maintained separately in the [main LabLink repository](https://github.com/talmolab/lablink). **Most users should use the pre-built images** (`ghcr.io/talmolab/lablink-allocator-image` and `ghcr.io/talmolab/lablink-client-base-image`). See [USE_CASES.md](USE_CASES.md) to determine if you need to build custom images.

## Quick Start

### Prerequisites

- AWS account with appropriate permissions
- Docker installed locally (for testing)
- Python 3.9+ with `uv` package manager

### Getting Started

1. **Use this template** - Click "Use this template" button on GitHub to create your own repository

2. **Configure your deployment** - Copy example files and customize:

```bash
# Configuration file
cd lablink-allocator/lablink-allocator-service/conf
cp config.yaml.example config.yaml
# Edit config.yaml with your AWS region, machine types, etc.

# Environment variables
cd lablink-allocator/lablink-allocator-service
cp .env.example .env
# Edit .env with your AWS credentials and secrets

# Terraform variables
cd lablink-allocator
cp terraform.tfvars.example terraform.tfvars
# Edit terraform.tfvars with your DNS settings
```

3. **Update placeholders** - Replace `YOUR_ORG` and `YOUR_REPO` in:
   - [config.yaml](lablink-allocator/lablink-allocator-service/conf/config.yaml.example)
   - GitHub Actions workflows (if needed)
   - Docker image references

4. **Set up GitHub secrets** (for CI/CD):
   - `AWS_ROLE_ARN` - AWS IAM role for OIDC authentication
   - `GITHUB_TOKEN` - Auto-provided for GHCR access

See [TEMPLATE_SETUP.md](TEMPLATE_SETUP.md) for detailed setup instructions.

#### DNS Configuration

DNS is optional and can be configured in `config.yaml`:

```yaml
dns:
  enabled: true  # Set to false to use IP addresses only
  domain: "example.com"  # Your domain name
  app_name: "lablink"  # Application name for subdomains
  pattern: "auto"  # DNS naming pattern
```

**DNS Patterns:**

- **`auto`** (recommended): Environment-based subdomain
  - Production: `lablink.example.com`
  - Test: `test.lablink.example.com`
  - Dev: `dev.lablink.example.com`

- **`app-only`**: Same subdomain for all environments
  - All environments: `lablink.example.com`

- **`custom`**: Use custom subdomain
  - Set `custom_subdomain: "my-custom.example.com"`

**To disable DNS:** Set `enabled: false` or leave `domain` empty. The allocator will use IP addresses only.

## Deployment

### Local Development

```bash
cd lablink-allocator/lablink-allocator-service
uv run python main.py
```

### Production Deployment

See the [GitHub Actions workflows](.github/workflows/) for CI/CD deployment examples.

## Repository Structure

```
lablink-template/
├── .github/workflows/          # CI/CD pipelines
│   ├── lablink-images.yml      # Build and push Docker images
│   └── lablink-allocator-terraform.yml  # Deploy infrastructure
├── lablink-allocator/          # VM allocator service
│   ├── lablink-allocator-service/
│   │   ├── conf/               # Configuration files
│   │   │   └── config.yaml.example
│   │   ├── .env.example        # Environment variables template
│   │   └── ...                 # Service code (add from original repo)
│   ├── Dockerfile              # Allocator Docker image
│   ├── main.tf                 # Terraform for allocator EC2
│   └── terraform.tfvars.example
└── lablink-client-base/        # Client VM base image
    └── lablink-client-base-image/
        ├── Dockerfile          # Client Docker image
        └── ...
```

## Documentation

- **[Use Cases Guide](USE_CASES.md)** - Should you use pre-built images or build your own?
- [Template Setup Guide](TEMPLATE_SETUP.md) - Detailed setup instructions
- [Configuration Examples](lablink-allocator/lablink-allocator-service/conf/config.yaml.example)
- [Allocator README](lablink-allocator/README.md)
- [Client Base Image README](lablink-client-base/lablink-client-base-image/README.md)

## License

BSD 2-Clause License - see [LICENSE](LICENSE) file for details