# DNS & SSL Configuration - Team Review

## Full Configuration Reference

```yaml
# Database configuration
db:
  dbname: "lablink_db"
  user: "lablink"
  password: "PLACEHOLDER_DB_PASSWORD"  # Injected from GitHub secret
  host: "localhost"
  port: 5432
  table_name: "vms"
  message_channel: "vm_updates"

# Client VM specifications
machine:
  machine_type: "g4dn.xlarge"
  image: "ghcr.io/talmolab/lablink-client-base-image:linux-amd64-latest-test"
  ami_id: "ami-0601752c11b394251"  # Ubuntu 24.04 with Docker + GPU drivers
  repository: "https://github.com/YOUR_ORG/YOUR_REPO.git"
  software: "sleap"
  extension: "slp"

# Allocator service configuration
allocator:
  image_tag: "linux-amd64-latest-test"  # Or version tag for production

# Application settings
app:
  admin_user: "admin"
  admin_password: "PLACEHOLDER_ADMIN_PASSWORD"  # Injected from GitHub secret
  region: "us-west-2"

# DNS configuration (SIMPLIFIED)
dns:
  enabled: false              # true = use domain, false = IP-only access
  domain: ""                  # Full domain name (e.g., "lablink.mylab.edu")
  terraform_managed: false    # true = Terraform manages A record, false = manual
  zone_id: ""                 # Optional: Route53 zone ID (leave empty for auto-lookup)

# SSL configuration (SIMPLIFIED)
ssl:
  enabled: false              # true = HTTPS, false = HTTP (use false for testing)
  provider: "letsencrypt"     # Options: "letsencrypt", "cloudflare"
  email: ""                   # Required for Let's Encrypt certificate notifications

# Elastic IP strategy
eip:
  strategy: "dynamic"         # "persistent" = reuse tagged EIP, "dynamic" = create new EIP
  tag_name: "lablink-eip"     # Tag prefix. Final tag: {tag_name}-{env} (e.g., lablink-eip-prod)

# S3 backend for Terraform state
bucket_name: "tf-state-lablink-allocator-bucket"
```

## Simplified DNS & SSL Section

```yaml
dns:
  enabled: false              # true = use domain, false = IP-only access
  domain: ""                  # Full domain name (e.g., "lablink.mylab.edu")
  terraform_managed: false    # true = Terraform manages A record, false = manual
  zone_id: ""                 # Optional: Route53 zone ID (leave empty for auto-lookup)

ssl:
  enabled: false              # true = HTTPS, false = HTTP (use false for testing)
  provider: "letsencrypt"     # Options: "letsencrypt", "cloudflare"
  email: ""                   # Required for Let's Encrypt certificate notifications

eip:
  strategy: "dynamic"         # "persistent" = reuse tagged EIP, "dynamic" = create new EIP
  tag_name: "lablink-eip-dynamic"     # Tag prefix. Final tag: {tag_name}-{env}
```

## Use Cases

### 1. IP-Only Testing (No DNS, No SSL)
```yaml
dns:
  enabled: false
ssl:
  enabled: false
eip:
  strategy: "dynamic"  # Creates new EIP each deployment
  tag_name: "lablink-eip-dynamic"
```
- **Access:** `http://<PUBLIC_IP>`
- **Use for:** Development, quick testing, POC
- **Infrastructure:** Flask on port 80, no Caddy
- **EIP:** Dynamic (new IP each time, cleaned up on destroy)

---

### 2. CloudFlare DNS + CloudFlare SSL
```yaml
dns:
  enabled: true
  domain: "lablink.mylab.edu"
  terraform_managed: false
ssl:
  enabled: true
  provider: "cloudflare"
eip:
  strategy: "persistent"  # Reuses existing EIP with this tag
  tag_name: "lablink-eip"
```
- **Access:** `https://lablink.mylab.edu`
- **Use for:** Production with CDN/DDoS protection
- **Infrastructure:** Flask on port 80, CloudFlare handles SSL
- **EIP:** Persistent (same IP reused across deployments)
- **Manual step:** Create A record in CloudFlare pointing to EIP

---

### 3. Route53 + Let's Encrypt (Manual DNS)
```yaml
dns:
  enabled: true
  domain: "lablink.mylab.edu"
  terraform_managed: false
ssl:
  enabled: true
  provider: "letsencrypt"
  email: "admin@mylab.edu"
eip:
  strategy: "persistent"  # Reuses existing EIP with this tag
  tag_name: "lablink-eip"
```
- **Access:** `https://lablink.mylab.edu`
- **Use for:** Production on AWS, full DNS control
- **Infrastructure:** Caddy handles SSL certificates
- **EIP:** Persistent (same IP reused across deployments)
- **Manual step:** Create A record in Route53 pointing to EIP

---

### 4. Route53 + Let's Encrypt (Terraform-Managed DNS)
```yaml
dns:
  enabled: true
  domain: "lablink-test.mylab.edu"
  terraform_managed: true
ssl:
  enabled: true
  provider: "letsencrypt"
  email: "admin@mylab.edu"
eip:
  strategy: "dynamic"  # Creates new EIP each deployment
  tag_name: "lablink-eip-dynamic"
```
- **Access:** `https://lablink-test.mylab.edu`
- **Use for:** Ephemeral test environments, full automation
- **Infrastructure:** Terraform creates/destroys A record, Caddy handles SSL
- **EIP:** Dynamic (new IP each time, A record updated automatically)
- **Manual step:** None (fully automated)

---

## Validation Rules

Config validation will prevent these invalid combinations:

| Invalid Combination | Error |
|---------------------|-------|
| `ssl.enabled: true` + `dns.enabled: false` | SSL requires a domain |
| `dns.enabled: true` + `dns.domain: ""` | Must specify domain when DNS enabled |
| `ssl.provider: "letsencrypt"` + `ssl.email: ""` | Let's Encrypt requires email |
| `ssl.provider: "cloudflare"` + `dns.provider: "route53"` | CloudFlare SSL requires CloudFlare DNS |

## Changes from Current Config

**Fields removed:**
- `dns.app_name` - specify full domain in `dns.domain`
- `dns.pattern` - specify full domain in `dns.domain`
- `dns.custom_subdomain` - specify full domain in `dns.domain`
- `dns.create_zone` - hosted zones must be pre-created
- `ssl.staging` - use `ssl.enabled: false` for testing

**Simplifications:**
- One domain field instead of subdomain + domain concatenation
- Config validation catches errors before deployment

## Testing Plan

**Integration tests for each use case:**
1. IP-only: Deploy → verify HTTP access at public IP → destroy
2. CloudFlare: Deploy → verify HTTPS + CloudFlare proxy → destroy
3. Route53 manual: Deploy → verify HTTPS + valid cert → destroy
4. Route53 automated: Deploy → verify DNS record created + HTTPS → destroy

## Questions for Discussion

1. Do these 4 use cases cover all deployment scenarios? Are they more than we want to cover?
2. Should we support HTTP-only with a domain (Case 5)?
3. Any required fields missing from the config? Or should any be removed?
