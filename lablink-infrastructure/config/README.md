# LabLink Configuration Guide

This directory contains example configuration files for different deployment scenarios. Choose the configuration that best matches your use case and infrastructure requirements.

## Quick Start

1. **Copy** the appropriate example config to `config.yaml`:
   ```bash
   cp lablink-infrastructure/config/<example>.yaml lablink-infrastructure/config/config.yaml
   ```

2. **Edit** `config.yaml` with your specific values (domain, region, etc.)

3. **Deploy** using the GitHub Actions workflow or manually with OpenTofu

## Configuration Selection Decision Tree

```
Do you need HTTPS/SSL?
├─ NO  → Use ip-only.example.yaml (fastest, simplest)
│
└─ YES → Do you have a domain name?
    ├─ NO  → You need a domain for SSL. Register one first.
    │
    └─ YES → Where is your DNS managed?
        ├─ CloudFlare      → Use cloudflare.example.yaml
        ├─ Route53 (AWS)   → Do you want OpenTofu to manage DNS records?
        │   ├─ YES → Use letsencrypt.example.yaml
        │   └─ NO  → Use letsencrypt-manual.example.yaml
        └─ Other DNS       → Use cloudflare.example.yaml or manual Route53 setup
```

## Configuration Comparison Table

| Config File | DNS Provider | SSL Provider | OpenTofu Manages DNS | Rate Limits | Use Case | Setup Complexity |
|-------------|--------------|--------------|----------------------|-------------|----------|------------------|
| **ip-only.example.yaml** | None (IP only) | None (HTTP) | N/A | None | Quick testing, development | ⭐ Low |
| **cloudflare.example.yaml** | CloudFlare | CloudFlare | No | None | Frequent testing, production with CloudFlare | ⭐⭐ Medium |
| **letsencrypt.example.yaml** | Route53 | Let's Encrypt | Yes | **5/week per domain** | Infrequent staging, stable production | ⭐⭐ Medium |
| **letsencrypt-manual.example.yaml** | Route53 | Let's Encrypt | No | **5/week per domain** | Manual DNS control, migrations | ⭐⭐⭐ Medium-High |
| **acm.example.yaml** | Route53 | AWS ACM (+ ALB) | Yes | None | Enterprise production (+$20/mo) | ⭐⭐⭐⭐ High |
| **dev.example.yaml** | Configurable | Configurable | Configurable | Varies | Local development (S3 state) | ⭐⭐ Medium |
| **test.example.yaml** | Configurable | Configurable | Configurable | Varies | Staging environment (S3 state) | ⭐⭐ Medium |
| **prod.example.yaml** | Configurable | Configurable | Configurable | Varies | Production deployment (S3 state) | ⭐⭐ Medium |
| **ci-test.example.yaml** | Route53 | Let's Encrypt | Yes | **5/week per domain** | Template maintainers only | ⭐⭐ Medium |

## Detailed Configuration Descriptions

### Use Case Configs (By Infrastructure Pattern)

These configs are organized by **how you want to set up DNS and SSL**:

#### ip-only.example.yaml
**Best for:** Quick testing, development, proof-of-concept

- **DNS:** Disabled (access via IP address)
- **SSL:** None (HTTP only)
- **EIP:** Dynamic (new IP each deployment)
- **Prerequisites:** None

**Pros:**
- Fastest setup
- No domain or DNS required
- No SSL rate limits
- Free (no additional AWS costs)

**Cons:**
- HTTP only (not secure for production)
- IP address changes on redeploy
- Different from production setup

**Access:** `http://<ALLOCATOR_IP>:5000`

---

#### cloudflare.example.yaml
**Best for:** Frequent testing, production deployments with CloudFlare

- **DNS:** CloudFlare (managed outside OpenTofu)
- **SSL:** CloudFlare (automatic via proxy)
- **EIP:** Persistent (stable IP)
- **Prerequisites:** CloudFlare account, domain managed in CloudFlare

⚠️ **Rate Limits:** None (CloudFlare SSL has no limits)

**Pros:**
- No Let's Encrypt rate limits
- DDoS protection included
- Free CloudFlare tier available
- Great for frequent redeployments

**Cons:**
- Requires CloudFlare account
- Manual DNS record creation
- Extra step in deployment workflow

**Setup:**
1. Deploy infrastructure
2. Create A record in CloudFlare: `your-domain.com` → `<ALLOCATOR_IP>`
3. Enable CloudFlare proxy (orange cloud icon)

**Access:** `https://your-domain.com`

---

#### letsencrypt.example.yaml
**Best for:** Production deployments with stable domain, infrequent staging tests

- **DNS:** Route53 (Terraform-managed)
- **SSL:** Let's Encrypt (automatic via Caddy)
- **EIP:** Persistent (stable IP)
- **Prerequisites:** Route53 hosted zone, domain nameservers pointed to Route53

⚠️ **Rate Limits:**
- **5 certificates per exact domain every 7 days** (e.g., `test.example.com`)
- 50 certificates per registered domain every 7 days (e.g., all `*.example.com`)
- Violations = **7-day lockout with NO override**

**What triggers a certificate:**
- First deployment
- Redeploy after `tofu destroy`
- DNS changes
- Caddy container restart with lost cache

**Pros:**
- Fully automated DNS + SSL
- Free certificates
- Production-ready HTTPS
- OpenTofu manages everything

**Cons:**
- Rate limits prevent frequent testing
- Requires Route53 hosted zone
- Can get locked out for 7 days

**When to use:**
- Production with stable domain
- Staging deployed 1-2 times per week max
- NOT for frequent testing/development

**Access:** `https://your-domain.com`

**See Also:** [TESTING_BEST_PRACTICES.md](../../docs/TESTING_BEST_PRACTICES.md) for rate limit strategies

---

#### letsencrypt-manual.example.yaml
**Best for:** Manual DNS control, migrations from existing setups

- **DNS:** Route53 (manual A record creation)
- **SSL:** Let's Encrypt (automatic via Caddy)
- **EIP:** Persistent (stable IP)
- **Prerequisites:** Route53 hosted zone, manually created A record

⚠️ **Rate Limits:** Same as `letsencrypt.example.yaml` - **5/week per domain**

**Pros:**
- Control over DNS records
- Good for migrations
- Let's Encrypt SSL still automatic

**Cons:**
- Extra manual step (create A record)
- Same rate limits as automated Let's Encrypt
- DNS not tracked in OpenTofu state

**Setup:**
1. Deploy infrastructure (note EIP from output)
2. Manually create A record in Route53 console: `your-domain.com` → `<EIP>`
3. Wait for DNS propagation
4. Caddy obtains Let's Encrypt certificate on first access

**Access:** `https://your-domain.com`

---

#### acm.example.yaml
**Best for:** Enterprise production with ALB

- **DNS:** Route53 (Terraform-managed)
- **SSL:** AWS Certificate Manager via Application Load Balancer
- **EIP:** N/A (ALB provides stable DNS)
- **Prerequisites:** Route53 hosted zone, ACM certificate requested and validated

⚠️ **Rate Limits:** None (AWS ACM has no limits)

💰 **Cost:** ALB adds ~$20/month

**Pros:**
- No SSL rate limits
- Enterprise-grade SSL termination
- AWS-managed certificates
- Scalable (ALB can handle multiple targets)

**Cons:**
- Additional cost (~$20/mo for ALB)
- More complex setup (ACM certificate validation)
- Requires ALB configuration

**Setup:**
1. Request ACM certificate in AWS console
2. Validate certificate (DNS or email)
3. Copy certificate ARN to `ssl.certificate_arn`
4. Deploy infrastructure

**Access:** `https://your-domain.com`

---

### Environment Configs (By Deployment Environment)

These configs are organized by **where/how you're deploying** (dev vs test vs prod):

#### dev.example.yaml
**Best for:** Local development against its own S3 state key

- **State Storage:** S3, `dev/terraform.tfstate`
- **DNS/SSL:** Configurable (usually IP-only for dev)
- **Usage:** Local development and testing

**Key Differences:**
- Separate state key keeps local experiments off `test`/`prod` state
- Usually deployed from local machine
- Not intended for CI/CD workflows

**When to use:**
- Developing OpenTofu changes
- Testing infrastructure modifications locally
- Quick prototyping

---

#### test.example.yaml
**Best for:** Staging/pre-production environment

- **State Storage:** S3 + DynamoDB locking
- **DNS/SSL:** Configurable (recommend CloudFlare or IP-only for frequent tests)
- **Usage:** Staging environment for validation before production

**Key Differences:**
- S3 backend for state
- Deployed via GitHub Actions or CI/CD
- Environment name: `test`

**When to use:**
- Staging environment
- Pre-production validation
- Testing with team

⚠️ **Recommendation:** Use CloudFlare SSL or IP-only to avoid Let's Encrypt rate limits during frequent testing.

---

#### prod.example.yaml
**Best for:** Production deployments

- **State Storage:** S3 + DynamoDB locking
- **DNS/SSL:** Configurable (recommend Let's Encrypt or ACM for production)
- **Usage:** Production environment serving real users

**Key Differences:**
- S3 backend for state
- Deployed via GitHub Actions or CI/CD
- Environment name: `prod`
- Should have monitoring and backups enabled

**When to use:**
- Production deployments
- Serving real users
- Stable, infrequent changes

**Recommendations:**
- Use persistent EIP
- Use Let's Encrypt or ACM for SSL
- Set up monitoring and alerts
- Enable backups

---

#### ci-test.example.yaml
**Best for:** Template maintainers testing infrastructure changes

- **State Storage:** S3 + DynamoDB locking
- **DNS/SSL:** Route53 + Let's Encrypt
- **Usage:** Template repository testing only

⚠️ **Rate Limits:** **5 deployments per week** (Let's Encrypt limit)

**When to use:**
- Testing template infrastructure changes
- Validating PRs that modify OpenTofu
- Template maintainers only

**Important:**
- Do NOT use for regular development
- Coordinate with team to avoid simultaneous deploys
- Only run on significant infrastructure changes
- Consider IP-only for some tests

---

## Rate Limit Considerations

### Let's Encrypt Rate Limits

**Critical Limits:**
- **5 certificates per exact domain every 7 days** (e.g., `test.example.com`)
- 50 certificates per registered domain every 7 days (e.g., all `*.example.com`)
- **NO override available** for the 5/week limit

**What counts as a new certificate:**
- Each `tofu apply` (first time or after destroy)
- DNS changes
- Domain name changes
- Caddy container restart with lost certificate cache

**How to avoid rate limits:**

| Scenario | Recommended Config | Why |
|----------|-------------------|-----|
| Frequent testing (5+ deploys/week) | `cloudflare.example.yaml` or `ip-only.example.yaml` | No rate limits |
| Infrequent staging (1-2 deploys/week) | `letsencrypt.example.yaml` | Under rate limit threshold |
| Production (stable domain) | `letsencrypt.example.yaml` or `acm.example.yaml` | Minimal redeployments |
| Template testing | `ci-test.example.yaml` sparingly | Limit: 5/week |

**Monitor certificate usage:**
- Visit [crt.sh](https://crt.sh/?q=your-domain.com)
- Count certificates in last 7 days
- Calculate remaining: `5 - (count)`

**If you hit rate limits:**
1. Wait 7 days (sliding window)
2. Switch to different subdomain (`test2.example.com`)
3. Switch to `cloudflare.example.yaml` (no limits)
4. Switch to `ip-only.example.yaml` (no SSL)

See [TESTING_BEST_PRACTICES.md](../../docs/TESTING_BEST_PRACTICES.md) for comprehensive rate limit strategies.

---

## Configuration File Structure

All configuration files follow this structure:

```yaml
deployment_name: "..." # Resource-name prefix; must match -var="deployment_name=..."
environment: "..."     # dev | test | ci-test | prod; must match -var="environment=..."

db:                    # Database configuration (password is the only key)
  password: "PLACEHOLDER_DB_PASSWORD"  # Replaced by GitHub secret

machine:               # Client VM configuration
  machine_type: "..."  # EC2 instance type
  image: "..."         # Docker image for client
  ami_id: "..."        # AWS AMI (region-specific)
  repository: "..."    # Git repo to clone (optional)

allocator:             # Allocator service configuration
  image_tag: "..."     # Docker image tag

app:                   # Application settings
  admin_user: "..."
  admin_password: "PLACEHOLDER_ADMIN_PASSWORD"  # Replaced by GitHub secret
  region: "..."        # AWS region

dns:                   # DNS configuration
  enabled: true/false
  terraform_managed: true/false
  domain: "..."
  zone_id: "..."       # Route53 zone (auto-lookup if empty)

eip:                   # Elastic IP configuration
  strategy: "persistent" or "dynamic"
                       # Name is {deployment_name}-eip-{environment}

ssl:                   # SSL configuration
  provider: "letsencrypt" | "cloudflare" | "acm" | "none"
  email: "..."         # For Let's Encrypt
  certificate_arn: ""  # For ACM

startup_script:        # Custom startup script (optional)
  enabled: false
  path: "..."
  on_error: "continue" or "fail"

bucket_name: "..."     # S3 bucket for OpenTofu state
```

### Deployment Identity

`deployment_name` and `environment` must match the `-var` values passed to OpenTofu. The
deploy workflow overwrites both from its own inputs, so they always agree there; running
OpenTofu locally, you keep them in sync yourself. The allocator reads them from this file
(it is copied verbatim onto the instance) and scopes client VM state to
`s3://{bucket_name}/{deployment_name}/{environment}/`. Its IAM policy grants exactly that
prefix and nothing else, so a mismatch surfaces as AccessDenied when the allocator
provisions client VMs — long after a green `tofu apply`.

### Instance Types and AMIs

| `machine.machine_type` | Notes |
|------------------------|-------|
| `g4dn.xlarge` | NVIDIA T4 GPU — the usual choice for SLEAP/ML workloads |
| `g5.2xlarge` | NVIDIA A10G, more VRAM |
| `t3.large` | CPU-only, cheapest for testing |
| `p3.2xlarge` | NVIDIA V100, heavier training |

`machine.ami_id` is **region-specific**: `ami-0601752c11b394251` is the Ubuntu 24.04 +
Docker + NVIDIA driver AMI in `us-west-2`. There is a second, separate AMI for the
allocator itself (`ami-0bd08c9d4aa9f0bc6`, Ubuntu 24.04 + Docker), also us-west-2 only.
It has no `config.yaml` field — the allocator's schema has none, and any extra key makes
the config fail validation — so it is passed to OpenTofu as
`-var="allocator_ami_id=ami-..."`. Changing `app.region` means changing both, plus the
`AWS_REGION` GitHub secret.

`allocator.image_tag` selects the allocator container image. `linux-amd64-latest-test`
tracks the latest test build; pin a version such as `linux-amd64-v1.2.3` for production.

### Domain Naming

`dns.domain` is the **full** domain name for the allocator — `lablink.example.com` or
`test.lablink.example.com`. Nothing is constructed for you: no environment prefix is
prepended, so whatever you write is exactly what gets served and certified.

## Common Configuration Tasks

### Change Domain Name

```bash
# Edit config.yaml
sed -i 's/domain: "old.example.com"/domain: "new.example.com"/' \
  lablink-infrastructure/config/config.yaml

# If using terraform_managed: true, OpenTofu will update DNS automatically
# If using terraform_managed: false, manually update A record in DNS provider
```

### Change AWS Region

`app.region` is what decides where the deployment lands: the OpenTofu AWS provider reads
it, `scripts/init-terraform.sh` points the S3 backend at it, and the allocator uses it to
provision client VMs.

```yaml
app:
  region: "eu-west-1"      # your new region
machine:
  ami_id: "ami-XXXXXXXX"   # client AMI, must exist in eu-west-1
```

Then supply an allocator AMI for the new region at apply time — it is a `-var`, not a
config field:

```bash
tofu apply -var="deployment_name=YOUR-DEPLOYMENT" -var="environment=test" \
  -var="allocator_ami_id=ami-YOUR-ALLOCATOR-COPY"
```

Both bundled images are custom builds with Docker pre-installed, and `user_data.sh`
depends on that — it starts the Docker daemon rather than installing it, so a stock
Ubuntu AMI is not a drop-in. Copy the existing ones instead:

```bash
aws ec2 copy-image --source-region us-west-2 \
  --source-image-id ami-0bd08c9d4aa9f0bc6 \
  --region eu-west-1 --name lablink-allocator-ubuntu24-docker
```

Omitting the allocator AMI is caught at plan time with an explanatory error rather than
failing partway through apply.

Also update the `AWS_REGION` GitHub secret so the workflows authenticate in the same
region.

### Switch from Let's Encrypt to CloudFlare

```bash
# Start with cloudflare.example.yaml
cp lablink-infrastructure/config/cloudflare.example.yaml \
   lablink-infrastructure/config/config.yaml

# Edit values (domain, bucket, region)
nano lablink-infrastructure/config/config.yaml

# Deploy
# Then create A record in CloudFlare console
```

### Switch from HTTPS to IP-Only (Rate Limit Recovery)

```bash
# Edit config.yaml
# Set:
#   dns.enabled: false
#   ssl.provider: "none"
#   eip.strategy: "dynamic"

# Or use ip-only template
cp lablink-infrastructure/config/ip-only.example.yaml \
   lablink-infrastructure/config/config.yaml

# Deploy - access via http://<IP>:5000
```

## Validation

Validate your configuration before deploying:

```bash
# Using Docker (recommended)
docker run --rm \
  -v "$(pwd)/lablink-infrastructure/config/config.yaml:/config/config.yaml:ro" \
  ghcr.io/talmolab/lablink-allocator-image:latest \
  uv run lablink-validate-config /config/config.yaml --verbose

# Validation checks:
# - DNS enabled requires non-empty domain
# - SSL (non-"none") requires DNS enabled
# - Let's Encrypt requires email
# - ACM requires certificate_arn
# - CloudFlare SSL requires terraform_managed: false
```

## Troubleshooting

### Configuration Not Loading

**Error:** `Failed to read bucket_name or region from config.yaml`

**Solution:**
- Ensure file is named `config.yaml` (not `config.yml`)
- Verify file is in `lablink-infrastructure/config/` directory
- Check YAML syntax with a validator

### Validation Fails

**Error:** `DNS enabled requires non-empty domain field`

**Solution:**
- Set `dns.domain` to your domain name
- Or set `dns.enabled: false` for IP-only deployment

### Let's Encrypt Certificate Fails

**Error:** `too many certificates already issued for exact set of domains`

**Solution:**
- You've hit the rate limit (5 certificates/week)
- See [MANUAL_CLEANUP_GUIDE.md](../../docs/MANUAL_CLEANUP_GUIDE.md#scenario-6-lets-encrypt-rate-limit-reached) for recovery options

## Additional Resources

- [Main README](../../README.md) - Overview and quick start
- [Deployment Checklist](../../docs/DEPLOYMENT_CHECKLIST.md) - Step-by-step deployment guide
- [Testing Best Practices](../../docs/TESTING_BEST_PRACTICES.md) - Rate limit strategies
- [Manual Cleanup Guide](../../docs/MANUAL_CLEANUP_GUIDE.md) - Troubleshooting and cleanup
- [Infrastructure README](../README.md) - OpenTofu documentation