## Why

The lablink allocator package has implemented breaking changes to DNS and SSL configuration (talmolab/lablink#230) that simplify domain management, add ACM support, and fix security vulnerabilities. The lablink-template infrastructure repository must be updated to support the new configuration schema before the new allocator package version is released to PyPI.

**Problems Being Solved:**
1. **Subdomain takeover vulnerability**: Current pattern-based subdomain construction creates dangling DNS records that persist after infrastructure destruction
2. **Configuration complexity**: Users must understand pattern logic, app_name, and custom_subdomain interactions
3. **Missing ACM support**: No way to use AWS Certificate Manager for SSL (enterprise requirement)
4. **Inconsistent FQDN**: FQDN computed in multiple places (Terraform, allocator, Lambda) leading to URL mismatches
5. **No config validation in CI**: Invalid configs only discovered at deployment time (fail slow)

**Security Context:**
- Sub-subdomains (test.lablink.sleap.ai) ARE allowed and NOT a security issue
- Real security fix is DNS lifecycle management (cleanup on destroy)
- Terraform lifecycle hooks will prevent dangling DNS records

## What Changes

### Configuration Schema (BREAKING CHANGES)
**DNS Configuration:**
- **REMOVED**: `dns.app_name`, `dns.pattern`, `dns.custom_subdomain`, `dns.create_zone`
- **CHANGED**: `dns.domain` now accepts full domain (e.g., "lablink.sleap.ai" or "test.lablink.sleap.ai")
- **ADDED**: DNS lifecycle hooks to prevent dangling records

**SSL Configuration:**
- **REMOVED**: `ssl.staging` (Let's Encrypt staging no longer configurable)
- **ADDED**: `ssl.provider` now supports "acm" (in addition to "none", "letsencrypt", "cloudflare")
- **ADDED**: `ssl.certificate_arn` (required when provider="acm")

### Infrastructure Changes

**Terraform DNS (main.tf):**
- Remove pattern-based subdomain construction logic (lines 223-230)
- Use `dns.domain` directly as FQDN
- Add lifecycle hooks to Route53 records (prevent_destroy for prod)
- Support sub-subdomains natively

**FQDN Computation (main.tf, user_data.sh):**
- Compute FQDN in Terraform based on: dns.enabled + dns.domain + ssl.provider
- Pass `ALLOCATOR_FQDN` environment variable to allocator container
- Format: "https://lablink.sleap.ai" or "http://52.40.142.146" (IP-only)
- Remove FQDN computation from user_data.sh (single source of truth)

**SSL/Caddy Configuration:**
- Remove ssl.staging logic from user_data.sh
- Conditional Caddy installation based on ssl.provider (only for letsencrypt/cloudflare)
- ACM/ALB stack does not need Caddy

**ACM/ALB Support (new files):**
- Create alb.tf for Application Load Balancer resources
- Conditional creation when ssl.provider="acm"
- ALB target group pointing to allocator EC2 on port 5000
- Security group updates to allow ALB → EC2 traffic
- Attach ACM certificate from ssl.certificate_arn

**Configuration Examples:**
- Update config.yaml (current ci-test config)
- Create config/test.example.yaml
- Create config/prod.example.yaml
- Create config/acm.example.yaml
- Remove deprecated fields from all examples

**CI Validation (.github/workflows):**
- Add config-validation.yml workflow
- Trigger on PRs affecting config/*.yaml
- Install lablink-allocator package
- Run lablink-validate-config
- Block merge if validation fails

## Impact

**Affected Specs:**
- infrastructure/terraform-configuration (DNS/SSL logic)
- infrastructure/deployment-automation (FQDN environment variable)
- infrastructure/ssl-configuration (ACM support)

**Affected Code:**
- lablink-infrastructure/main.tf (DNS, FQDN computation, locals)
- lablink-infrastructure/user_data.sh (ALLOCATOR_FQDN usage, Caddy conditional)
- lablink-infrastructure/alb.tf (NEW - ACM/ALB stack)
- lablink-infrastructure/config/config.yaml (schema update)
- lablink-infrastructure/config/*.example.yaml (NEW examples)
- .github/workflows/config-validation.yml (NEW workflow)
- README.md (migration guide)

**Breaking Changes:**
- ⚠️ **USERS MUST UPDATE CONFIGS** - Old configs will fail validation
- `dns.app_name`, `dns.pattern`, `dns.custom_subdomain`, `dns.create_zone` → removed
- `dns.domain` → must be full domain (not base zone)
- `ssl.staging` → removed (always use production Let's Encrypt)

**Migration Path:**
- Old: `dns.domain="sleap.ai"`, `dns.app_name="lablink"`, `dns.pattern="auto"` → `test.lablink.sleap.ai`
- New: `dns.domain="test.lablink.sleap.ai"`

**Security Improvements:**
- DNS records deleted on terraform destroy (lifecycle hooks)
- FQDN validated pre-deployment (fail fast)
- Subdomain takeover risk eliminated

**Dependencies:**
- Requires lablink-allocator package with new validation rules
- Requires Python 3.11+ for lablink-validate-config CLI
- ACM certificates must be pre-created (not managed by Terraform)

**5 Canonical Use Cases:**
1. **IP-only**: dns.enabled=false, ssl.provider="none" → http://52.40.142.146
2. **CloudFlare**: dns.enabled=false, ssl.provider="cloudflare" → https://lablink.sleap.ai (managed in CloudFlare)
3. **Route53 + Let's Encrypt (Terraform)**: dns.enabled=true, terraform_managed=true, ssl.provider="letsencrypt"
4. **Route53 + ACM**: dns.enabled=true, terraform_managed=true, ssl.provider="acm"
5. **Route53 + Let's Encrypt (Manual)**: dns.enabled=true, terraform_managed=false, ssl.provider="letsencrypt"