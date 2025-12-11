# DNS and SSL Configuration Simplification Plan

## Executive Summary

We're simplifying the DNS and SSL configuration to support 4 clear use cases, removing redundancies and conflicts in the current config structure. This plan outlines the proposed configuration schema, use cases, and testing strategy.

## Current Problems

1. **Caddy misconfiguration**: When DNS is disabled, Caddy is configured with `http://N/A` which doesn't listen on port 80
2. **Config redundancy**: Multiple overlapping settings (`dns.*`, `ssl.*`) with unclear interactions
3. **Invalid combinations**: Config allows impossible combinations (e.g., SSL without DNS)
4. **Missing validation**: No early validation catches misconfigurations before deployment
5. **Unnecessary complexity**: Caddy installed even when not needed (CloudFlare or IP-only cases)

## Supported Use Cases

### Use Case 1: IP-Only Access (Development/Testing)
**Scenario**: Access allocator via public IP, no domain, no SSL

**Configuration**:
```yaml
dns:
  enabled: false

ssl:
  enabled: false
```

**Infrastructure**:
- No Caddy (Flask serves directly on port 80)
- No Route53 records
- EIP (persistent or dynamic)
- Access: `http://<PUBLIC_IP>`

**When to use**: Local testing, development, POC deployments

---

### Use Case 2: CloudFlare DNS + CloudFlare SSL
**Scenario**: Domain on CloudFlare with CloudFlare's SSL proxy (orange cloud)

**Configuration**:
```yaml
dns:
  enabled: true
  domain: "lablink.mylab.edu"  # Full domain name
  terraform_managed: false      # DNS managed in CloudFlare UI

ssl:
  enabled: true
  provider: "cloudflare"
```

**Infrastructure**:
- No Caddy (Flask serves HTTP on port 80)
- No Route53 records (managed in CloudFlare)
- EIP (persistent recommended)
- CloudFlare terminates SSL
- Access: `https://lablink.mylab.edu` (via CloudFlare)

**When to use**: Production with CloudFlare CDN, DDoS protection needed

**Manual steps**: Create A record in CloudFlare pointing `lablink.mylab.edu` to EIP

---

### Use Case 3: AWS Route53 + Let's Encrypt SSL (Manual DNS)
**Scenario**: Domain on Route53, SSL via Let's Encrypt, manually managed DNS

**Configuration**:
```yaml
dns:
  enabled: true
  domain: "lablink.mylab.edu"  # Full domain name
  terraform_managed: false      # DNS managed manually in Route53

ssl:
  enabled: true
  provider: "letsencrypt"
  email: "admin@mylab.edu"
```

**Infrastructure**:
- Caddy installed (handles Let's Encrypt + HTTPS)
- Route53 hosted zone (pre-existing)
- EIP (persistent recommended)
- Access: `https://lablink.mylab.edu`

**When to use**: Production on AWS, full control over DNS, automated SSL renewal

**Manual steps**: Create A record in Route53 pointing `lablink.mylab.edu` to EIP

---

### Use Case 4: AWS Route53 + Let's Encrypt SSL (Terraform-Managed DNS)
**Scenario**: Fully automated - Terraform manages DNS and SSL

**Configuration**:
```yaml
dns:
  enabled: true
  domain: "lablink-test.mylab.edu"  # Full domain name
  terraform_managed: true            # Terraform creates/destroys A record

ssl:
  enabled: true
  provider: "letsencrypt"
  email: "admin@mylab.edu"
```

**Infrastructure**:
- Caddy installed (handles Let's Encrypt + HTTPS)
- Route53 hosted zone (pre-existing)
- EIP (dynamic or persistent)
- Terraform creates/destroys A record
- Access: `https://lablink-test.mylab.edu`

**When to use**: Ephemeral environments, test deployments, full IaC

**Manual steps**: None (fully automated)

---

## Proposed Configuration Schema

### Simplified Config Structure

```yaml
dns:
  enabled: false              # true = use domain, false = IP-only access
  domain: ""                  # Required if enabled=true. Full domain name (e.g., "lablink.mylab.edu")
  terraform_managed: false    # true = Terraform creates A record, false = manual DNS
  zone_id: ""                 # Optional: Route53 zone ID (auto-lookup if empty)

ssl:
  enabled: false              # true = HTTPS, false = HTTP only (use false for testing)
  provider: "letsencrypt"     # "letsencrypt" or "cloudflare"
  email: ""                   # Required for Let's Encrypt
```

### Fields Removed
- `dns.app_name` - redundant, specify full domain name in `dns.domain`
- `dns.pattern` - redundant, specify full domain name in `dns.domain`
- `dns.custom_subdomain` - redundant, specify full domain name in `dns.domain`
- `dns.create_zone` - zones should be pre-created (persistent infrastructure outlives deployments)
- `ssl.staging` - redundant, use `ssl.enabled: false` for testing with HTTP

### Validation Rules

**Invalid combinations that should error:**
1. `ssl.enabled: true` AND `dns.enabled: false` → ❌ Can't have SSL without domain
2. `ssl.provider: "letsencrypt"` AND `dns.enabled: false` → ❌ Need domain for Let's Encrypt
3. `dns.terraform_managed: true` AND `dns.enabled: false` → ❌ Can't manage DNS if DNS disabled
4. `dns.enabled: true` AND `dns.domain: ""` → ❌ Need domain if DNS enabled
5. `ssl.enabled: true` AND `ssl.provider: "letsencrypt"` AND `ssl.email: ""` → ❌ Need email for LE

**Valid combinations:**

| dns.enabled | ssl.enabled | ssl.provider | Caddy? | Use Case |
|-------------|-------------|--------------|--------|----------|
| false       | false       | N/A          | No     | 1: IP-only |
| true        | true        | cloudflare   | No     | 2: CloudFlare |
| true        | true        | letsencrypt  | Yes    | 3: Route53 + LE (manual) |
| true        | true        | letsencrypt  | Yes    | 4: Route53 + LE (Terraform) |
| true        | false       | N/A          | No     | HTTP-only with domain |

## Implementation Changes

### 1. User Data Script (`user_data.sh`)

**Current flow**:
- Always installs Caddy
- Configures Caddy with `http://${DOMAIN_NAME}` (breaks when DOMAIN_NAME="N/A")

**Proposed flow**:
```bash
# Conditionally install Caddy
if [ "${SSL_ENABLED}" = "true" ] && [ "${SSL_PROVIDER}" = "letsencrypt" ]; then
  # Install Caddy for Let's Encrypt
  install_caddy
  configure_caddy_with_domain "${DOMAIN}"

elif [ "${DNS_ENABLED}" = "false" ]; then
  # IP-only: No Caddy, expose Flask on port 80
  # Reconfigure Flask to listen on 0.0.0.0:80

else
  # CloudFlare or HTTP-only with domain: No SSL needed
  # Could use simple Caddy config or expose Flask directly
fi
```

### 2. Terraform Variables (`main.tf`)

**Add new locals**:
```hcl
locals {
  # DNS
  dns_enabled = try(local.config_file.dns.enabled, false)
  dns_domain = try(local.config_file.dns.domain, "")
  dns_terraform_managed = try(local.config_file.dns.terraform_managed, false)
  dns_zone_id = try(local.config_file.dns.zone_id, "")

  # SSL
  ssl_enabled = try(local.config_file.ssl.enabled, false)
  ssl_provider = try(local.config_file.ssl.provider, "letsencrypt")
  ssl_email = try(local.config_file.ssl.email, "")

  # Derived values
  install_caddy = local.ssl_enabled && local.ssl_provider == "letsencrypt"
  domain_name = local.dns_enabled ? local.dns_domain : ""
}
```

**Remove old locals**:
- All the old `dns_*` fields that are redundant

### 3. Config Validation

**Add validation step in deploy workflow** (before Terraform):
```yaml
- name: Validate Config Schema
  run: |
    pip install lablink-allocator-service
    lablink-validate-config lablink-infrastructure/config/config.yaml
```

**Validation checks** (in allocator package):
- Config schema matches Hydra schema
- No invalid field combinations
- Required fields present when needed

### 4. Security Group Rules

**Current**: Port 80 always open

**Proposed**:
- Port 80: Always open (HTTP)
- Port 443: Only open if `ssl.enabled: true` and `ssl.provider: "letsencrypt"`

### 5. Flask Configuration

**Current**: Always runs on `0.0.0.0:5000` behind Caddy

**Proposed**:
- If Caddy installed: Run on `127.0.0.1:5000` (behind Caddy proxy)
- If no Caddy: Run on `0.0.0.0:80` (direct access)

## Testing Strategy

### 1. Pre-Deployment Validation (CI)

**Add to deploy workflow**:
```yaml
- name: Validate Config
  run: |
    pip install lablink-allocator-service
    lablink-validate-config config/config.yaml
```

**What it checks**:
- Schema validation (Hydra)
- Invalid combinations
- Required fields

### 2. Unit Tests (Terraform)

**Add tests**:
- `terraform validate` (already have)
- `terraform fmt -check` (already have)
- Config validation tests (new)

### 3. Integration Tests (Post-Deployment)

**Add scenario-based health checks**:

```yaml
- name: Health Check
  run: |
    if [ "$DNS_ENABLED" = "true" ]; then
      # Test DNS resolution
      nslookup $DOMAIN

      if [ "$SSL_ENABLED" = "true" ]; then
        # Test HTTPS
        curl -f https://$DOMAIN
      else
        # Test HTTP
        curl -f http://$DOMAIN
      fi
    else
      # Test IP-only access
      curl -f http://$PUBLIC_IP
    fi
```

### 4. Manual Test Matrix

| Scenario | DNS | SSL | Provider | Expected Behavior |
|----------|-----|-----|----------|-------------------|
| IP-only | ❌ | ❌ | N/A | HTTP on port 80, no Caddy, access via IP |
| CloudFlare | ✅ | ✅ | cloudflare | HTTP on port 80, no Caddy, CloudFlare terminates SSL |
| Route53 + LE (manual) | ✅ | ✅ | letsencrypt | HTTPS via Caddy, manual A record |
| Route53 + LE (Terraform) | ✅ | ✅ | letsencrypt | HTTPS via Caddy, Terraform A record |
| HTTP-only + domain | ✅ | ❌ | N/A | HTTP on port 80, no SSL |

**Test checklist for each scenario**:
- [ ] Deploy succeeds
- [ ] Service is accessible at correct URL
- [ ] SSL certificate valid (if applicable)
- [ ] DNS resolves correctly (if applicable)
- [ ] Destroy succeeds
- [ ] No orphaned resources

### 5. Automated Scenario Testing (Future)

**GitHub Actions matrix**:
```yaml
strategy:
  matrix:
    scenario:
      - name: ip-only
        dns_enabled: false
        ssl_enabled: false
      - name: cloudflare
        dns_enabled: true
        ssl_enabled: true
        ssl_provider: cloudflare
      - name: letsencrypt
        dns_enabled: true
        ssl_enabled: true
        ssl_provider: letsencrypt
```

## Migration Plan

### Phase 1: Quick Fix (Immediate)
1. Fix IP-only case to use `:80` instead of `http://N/A`
2. Add config validation CLI to allocator package
3. Add validation step to deploy workflow

### Phase 2: Config Simplification (Next PR)
1. Update config schema (remove redundant fields)
2. Update Terraform to use new schema
3. Update documentation
4. Add validation rules

### Phase 3: Conditional Caddy (Future)
1. Skip Caddy installation when not needed
2. Expose Flask directly for IP-only and CloudFlare cases
3. Update security group rules

### Phase 4: Automated Testing (Future)
1. Add scenario-based integration tests
2. Set up test matrix for all use cases
3. Add DNS/SSL validation tests

## Example Configurations

### Example 1: Development (IP-only)
```yaml
dns:
  enabled: false

ssl:
  enabled: false

eip:
  strategy: "dynamic"
  tag_name: "lablink-eip"
```

### Example 2: Production (CloudFlare)
```yaml
dns:
  enabled: true
  domain: "lablink.mylab.edu"  # Full domain name
  terraform_managed: false

ssl:
  enabled: true
  provider: "cloudflare"

eip:
  strategy: "persistent"
  tag_name: "lablink-eip"
```

### Example 3: Production (AWS + Let's Encrypt)
```yaml
dns:
  enabled: true
  domain: "lablink.mylab.edu"  # Full domain name
  terraform_managed: false
  zone_id: "Z1234567890ABC"

ssl:
  enabled: true
  provider: "letsencrypt"
  email: "admin@mylab.edu"

eip:
  strategy: "persistent"
  tag_name: "lablink-eip"
```

### Example 4: Test Environment (Fully Automated)
```yaml
dns:
  enabled: true
  domain: "lablink-test.mylab.edu"  # Full domain name
  terraform_managed: true
  zone_id: "Z1234567890ABC"

ssl:
  enabled: true
  provider: "letsencrypt"
  email: "admin@mylab.edu"

eip:
  strategy: "dynamic"
  tag_name: "lablink-eip-test"
```

## Questions for Team

1. **Use cases**: Do these 4 use cases cover all our deployment scenarios?
2. **Config schema**: Does the simplified schema make sense? Any missing fields?
3. **CloudFlare**: Should we support CloudFlare SSL proxy? (Removes Caddy complexity)
4. **Migration**: Can we migrate existing deployments, or only apply to new ones?
5. **Testing**: Which scenarios should we prioritize for automated testing?
6. **Timeline**: Phase 1 (quick fix) now, Phase 2 (simplification) next sprint?

## Next Steps

1. **Team review** of this plan
2. **Agreement** on final config schema and use cases
3. **Implementation** of Phase 1 (quick fix for IP-only)
4. **Update** allocator package with validation CLI
5. **Testing** of each scenario manually
6. **Documentation** update with new config structure
