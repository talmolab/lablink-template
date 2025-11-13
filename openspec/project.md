# Project Context

## Purpose
LabLink Infrastructure Template is a GitHub template repository for deploying LabLink infrastructure to AWS. LabLink automates deployment and management of cloud-based VMs for running research software, providing web-based VM provisioning, GPU support for ML/AI workloads, and Chrome Remote Desktop access.

**Key Goals:**
- Provide turnkey infrastructure deployment for research labs
- Support multi-environment deployments (test, prod, ci-test)
- Ensure safe, repeatable infrastructure management
- Enable configuration-driven customization without code changes

## Tech Stack

### Infrastructure & Deployment
- **Terraform 1.6+** - Infrastructure as Code for AWS resource provisioning
- **AWS Services** - EC2, S3, DynamoDB, Route53, CloudWatch, Lambda, IAM, Security Groups
- **Docker** - Container runtime for allocator and client services
- **Caddy** - Reverse proxy and automatic SSL/TLS termination

### Programming Languages
- **HCL (HashiCorp Configuration Language)** - Terraform infrastructure definitions
- **Bash** - Automation scripts (setup, initialization, cleanup)
- **Python** - Lambda functions for log processing
- **YAML** - Service configuration (config.yaml)

### CI/CD & Automation
- **GitHub Actions** - Deployment workflows, configuration validation, destruction workflows
- **OIDC Authentication** - Secure AWS credential management via GitHub Actions
- **lablink-validate-config** - Configuration validation CLI tool

### External Services
- **GitHub Container Registry (GHCR)** - Docker image storage
- **Let's Encrypt** - Automatic SSL certificate provisioning (optional)
- **CloudFlare** - Alternative DNS/SSL provider (optional)

## Project Conventions

### Code Style

**Terraform:**
- Run `terraform fmt` before committing
- Use `terraform validate` to check syntax
- CI enforces `terraform fmt -check` validation
- Organize resources logically in main.tf

**Bash Scripts:**
- Use `set -e` for error handling
- Add descriptive comments for complex operations
- Validate prerequisites before execution
- Make scripts idempotent where possible

**YAML Configuration:**
- Validate using `lablink-validate-config` before deployment
- Use example files (*.example.yaml) as templates
- Never commit secrets (use placeholders like PLACEHOLDER_ADMIN_PASSWORD)

**Python:**
- Keep Lambda functions minimal and focused
- Use standard library where possible
- Handle errors gracefully with try/except blocks

### Architecture Patterns

**Multi-Environment Strategy:**
- Resource suffix pattern: `{resource}-{environment}` (e.g., lablink-allocator-test)
- Environment-specific backend configs: `backend-{env}.hcl`
- Shared configuration with environment overrides

**State Management:**
- Remote S3 backend for Terraform state (versioning enabled)
- DynamoDB table for state locking
- State files stored per environment: `terraform-{env}.tfstate`

**Secret Injection:**
- GitHub secrets stored separately from code
- Secrets injected at deployment time via sed replacement
- Placeholders in config.yaml replaced during deployment

**Configuration-Driven Infrastructure:**
- Single source of truth: `lablink-infrastructure/config/config.yaml`
- Configuration path hardcoded (do not move/rename)
- Changes to config trigger validation in CI

**DNS/SSL Flexibility:**
- Three modes: Route53 + Let's Encrypt, CloudFlare, IP-only
- Terraform-managed or manually-managed DNS records
- Elastic IP strategies: persistent (reusable) or dynamic

### Testing Strategy

**Configuration Validation:**
- Automated in CI on pull requests affecting config files
- Uses `lablink-validate-config` to check YAML structure
- Validates required fields and value constraints

**Deployment Verification:**
- Post-deployment health checks in GitHub Actions
- HTTP connectivity tests (200/301/302 status codes)
- HTTPS/SSL certificate validation (if Let's Encrypt enabled)
- DNS resolution verification (if DNS enabled)

**Manual Testing:**
- Smoke tests in ci-test environment before prod
- Verify allocator web interface accessibility
- Test VM provisioning functionality
- Validate SSH access and key distribution

### Git Workflow

**Branching Strategy:**
- `main` - Production-ready code
- `test` - Auto-deploys to test environment on push
- Feature branches: `{username}/{description}` (e.g., elizabeth/add-config-validation-ci)

**Commit Conventions:**
- Write descriptive commit messages explaining "why" not just "what"
- Reference issues/PRs where applicable
- Keep commits focused and atomic

**Pull Request Process:**
- Create PR from feature branch to main
- CI runs configuration validation automatically
- Manual review required before merge
- Squash commits on merge for clean history

**Deployment Triggers:**
- Manual: GitHub Actions → "Deploy LabLink Infrastructure" → Run workflow
- Automatic: Push to `test` branch triggers test deployment
- Destruction: Manual only with explicit confirmation

## Domain Context

**LabLink Ecosystem:**
- **Allocator Service**: Central VM management service running on EC2, provides web UI for creating/destroying client VMs
- **Client VMs**: User-facing VMs provisioned on-demand with research software pre-installed
- **Chrome Remote Desktop**: GUI access mechanism for client VMs
- **Research Software**: Custom software deployed via Docker containers (e.g., SLEAP for animal pose tracking)

**AWS Resource Naming:**
- Pattern: `{resource}-{suffix}` where suffix is environment name
- Security Groups: `lablink-allocator-sg-{env}`, `lablink-client-sg-{env}`
- EC2 Instances: `lablink-allocator-{env}`
- IAM Roles: `lablink-client-iam-role-{env}`

**Key Configuration Concepts:**
- **machine_type**: AWS instance type for client VMs (e.g., g4dn.xlarge for GPU)
- **ami_id**: Region-specific Ubuntu 24.04 AMI with Docker + NVIDIA drivers
- **allocator_image_tag**: Version tag for allocator Docker image (use specific versions for prod, latest-test for testing)
- **zone_id**: Route53 hosted zone ID for DNS management

## Important Constraints

**AWS Permissions Required:**
- EC2 (create/destroy instances, security groups, elastic IPs)
- S3 (state storage, bucket management)
- DynamoDB (state locking table)
- Route53 (optional, for DNS management)
- IAM (create roles for client VMs, OIDC provider configuration)
- CloudWatch (log groups, metric collection)

**Regional Limitations:**
- AMI IDs are region-specific (must update if changing AWS_REGION)
- Some instance types unavailable in certain regions
- Let's Encrypt rate limits apply per domain

**Configuration Constraints:**
- config.yaml path is hardcoded: `lablink-infrastructure/config/config.yaml`
- S3 bucket names must be globally unique across ALL AWS accounts
- Terraform state must not be deleted while infrastructure exists
- Environment suffix must be consistent across backend config and variable

**Security Requirements:**
- Never commit secrets to repository (use GitHub secrets)
- OIDC trust policy must restrict to specific repository
- IAM roles follow least-privilege principle
- Security groups restrict access appropriately

**Operational Constraints:**
- Destroy workflow requires explicit confirmation to prevent accidents
- Client VM destruction must happen before allocator destruction
- State locking prevents concurrent Terraform operations
- EIP allocation requires manual tagging for reuse

## External Dependencies

**Required External Services:**
- **AWS Account** - All infrastructure provisioned here
- **GitHub** - Repository hosting, Actions workflows, OIDC authentication, Container Registry
- **Domain Registrar** - (Optional) If using custom domain with Route53

**Optional External Services:**
- **CloudFlare** - Alternative DNS/SSL provider
- **Let's Encrypt** - Free SSL certificate authority (via Caddy)

**Critical External Packages:**
- `lablink-allocator-service` - Provides config validation CLI
- Docker images from `ghcr.io/talmolab/lablink-*`

**API/Service Integrations:**
- LabLink Allocator API (Lambda → Allocator log forwarding)
- AWS APIs (via Terraform and AWS CLI)
- GitHub OIDC provider (for credential assumption)

**Documentation Dependencies:**
- Main LabLink docs: https://talmolab.github.io/lablink/
- Terraform docs: https://www.terraform.io/docs
- AWS service documentation for EC2, Route53, etc.
