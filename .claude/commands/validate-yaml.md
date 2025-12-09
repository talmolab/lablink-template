# Validate YAML Configuration

Validate LabLink configuration files against the schema using Docker-based `lablink-validate-config`.

## Command

```bash
# Validate main config using Docker
docker run --rm -v "$(pwd)":/workspace \
  ghcr.io/talmolab/lablink-validate-config:latest \
  /workspace/lablink-infrastructure/config/config.yaml

# Validate all example configs
for config in lablink-infrastructure/config/*.example.yaml; do
  echo "Validating $(basename $config)..."
  docker run --rm -v "$(pwd)":/workspace \
    ghcr.io/talmolab/lablink-validate-config:latest \
    "/workspace/$config"
done
```

## What This Command Does

Claude will:
1. Run `lablink-validate-config` via Docker (no local installation needed)
2. Check for schema violations
3. Verify required fields are present
4. Validate value constraints (e.g., valid AWS regions, email formats)
5. Report clear error messages with field paths
6. Suggest fixes based on example configs

## Usage

Simply ask Claude:
```
Validate the YAML configuration
```

Or validate specific configs:
```
Validate lablink-infrastructure/config/ci-test.example.yaml
```

## Expected Output

### Success
```
✓ Configuration is valid

Validated fields:
  - db.password: PLACEHOLDER (OK - will be injected at deploy time)
  - machine.machine_type: g4dn.xlarge (OK)
  - app.region: us-west-2 (OK)
  - dns.enabled: true (OK)
  - ssl.provider: letsencrypt (OK)

No issues found.
```

### Schema Violations
```
✗ Configuration validation failed:

Error: Missing required field
  Field: app.region
  Location: config.yaml
  Fix: Add AWS region to app section:
    app:
      region: "us-west-2"

Error: Invalid value
  Field: ssl.provider
  Value: "invalid-provider"
  Location: config.yaml:57
  Allowed values: letsencrypt, cloudflare, acm, none
  Fix: Use one of the valid SSL providers
```

### Type Errors
```
✗ Type mismatch:

Error: Field type mismatch
  Field: dns.enabled
  Expected: boolean
  Got: string ("yes")
  Location: config.yaml:47
  Fix: Use true/false instead of "yes"/"no":
    dns:
      enabled: true
```

## Common Issues & Fixes

### Issue: Missing required field
**Error:**
```
Error: Missing required field 'app.region'
```

**Fix:**
Add the required field to config.yaml:
```yaml
app:
  admin_user: "admin"
  admin_password: "PLACEHOLDER_ADMIN_PASSWORD"
  region: "us-west-2"  # Add this line
```

### Issue: Invalid enum value
**Error:**
```
Error: Invalid value for ssl.provider: 'lets-encrypt'
Allowed: letsencrypt, cloudflare, acm, none
```

**Fix:**
Use the correct enum value:
```yaml
ssl:
  provider: "letsencrypt"  # Not "lets-encrypt"
```

### Issue: YAML syntax error
**Error:**
```
Error: YAML parse error at line 45
```

**Fix:**
Check YAML syntax:
- Proper indentation (2 spaces, no tabs)
- Quoted strings with special characters
- No trailing colons without values

### Issue: Placeholder not replaced
**Warning:**
```
Warning: Placeholder detected in production config
  Field: db.password
  Value: "PLACEHOLDER_DB_PASSWORD"

This is OK for test configs, but production deployments
should inject real secrets via GitHub Actions.
```

## Docker Image

The validation uses the official Docker image which ensures:
- Correct version of `lablink-validate-config`
- All dependencies included
- No pollution of local Python environment
- Consistent validation across all environments

**Image:** `ghcr.io/talmolab/lablink-validate-config:latest`

**Pulling the image:**
```bash
docker pull ghcr.io/talmolab/lablink-validate-config:latest
```

## Configuration Schema

The validator checks against this schema:

```yaml
# Required fields
db:
  password: string (required)
  dbname: string (required)
  user: string (required)

machine:
  machine_type: string (required) # EC2 instance type
  image: string (required)        # Docker image URI
  ami_id: string (required)       # AWS AMI ID

app:
  admin_user: string (required)
  admin_password: string (required)
  region: string (required)       # AWS region

# Optional fields
dns:
  enabled: boolean (default: false)
  terraform_managed: boolean (default: true)
  domain: string (required if enabled=true)
  zone_id: string (optional)

ssl:
  provider: enum[letsencrypt, cloudflare, acm, none] (default: none)
  email: string (required if provider=letsencrypt)
  certificate_arn: string (required if provider=acm)

eip:
  strategy: enum[persistent, dynamic] (default: dynamic)
  tag_name: string (default: "lablink-eip")

startup_script:
  enabled: boolean (default: false)
  path: string (default: "config/custom-startup.sh")
  on_error: enum[continue, fail] (default: "continue")

bucket_name: string (required for test/prod)
```

## CI Integration

Validation runs automatically in GitHub Actions using Docker:

**`.github/workflows/config-validation.yml`:**
```yaml
name: Validate Configuration

on:
  pull_request:
    paths:
      - 'lablink-infrastructure/config/**'

jobs:
  validate:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - name: Validate config.yaml
        run: |
          docker run --rm -v "$(pwd)":/workspace \
            ghcr.io/talmolab/lablink-validate-config:latest \
            /workspace/lablink-infrastructure/config/config.yaml
```

## Example Configs

Use example configs as templates:

- `dev.example.yaml` - Local development (no S3 backend)
- `ci-test.example.yaml` - CI testing environment
- `test.example.yaml` - Staging environment
- `prod.example.yaml` - Production environment
- `cloudflare.example.yaml` - CloudFlare SSL example
- `letsencrypt.example.yaml` - Let's Encrypt SSL example
- `acm.example.yaml` - AWS Certificate Manager example
- `ip-only.example.yaml` - No DNS, IP-only access

## Related Commands

- `/validate-terraform` - Validate Terraform code
- `/validate-bash` - Validate shell scripts
- `/deploy-test` - Deploy after validation passes