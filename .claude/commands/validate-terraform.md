# Validate OpenTofu Code

Validate OpenTofu formatting and syntax for lablink-infrastructure code.

## Command

```bash
# Check formatting (no changes made)
tofu fmt -check -recursive lablink-infrastructure/

# Validate syntax and configuration
cd lablink-infrastructure
tofu init -backend=false
tofu validate
```

## What This Command Does

Claude will:
1. Check all `.tf` files for proper formatting using `tofu fmt -check`
2. Initialize OpenTofu without backend configuration
3. Run `tofu validate` to check syntax and configuration
4. Report any errors with file:line references
5. Provide fix suggestions for common issues

## Usage

Simply ask Claude:
```
Validate OpenTofu code in lablink-infrastructure
```

Or use the validation command before committing:
```
Run /validate-terraform before I commit these changes
```

## Expected Output

### Success
```
✓ OpenTofu formatting is correct (all .tf files)
✓ OpenTofu configuration is valid
  - 15 resources defined
  - 3 data sources
  - 5 outputs
  - No errors found
```

### Formatting Issues
```
✗ OpenTofu formatting issues found:

lablink-infrastructure/main.tf
  - Line 45: Incorrect indentation (expected 2 spaces)
  - Line 78: Missing blank line between resources

Fix with: tofu fmt lablink-infrastructure/
```

### Syntax Errors
```
✗ OpenTofu validation failed:

Error: Invalid resource type
  on main.tf line 123:
  123: resource "aws_invalid_type" "example" {

The resource type "aws_invalid_type" is not recognized.
```

## Common Issues & Fixes

### Issue: "Module not installed"
**Error:**
```
Error: Module not installed
```

**Fix:**
```bash
cd lablink-infrastructure
tofu init
```

### Issue: "Provider not found"
**Error:**
```
Error: Could not load plugin
```

**Fix:**
```bash
cd lablink-infrastructure
tofu init -upgrade
```

### Issue: Providers still coming from registry.terraform.io
**Symptom:** `.terraform.lock.hcl` contains `provider "registry.terraform.io/..."`
entries.

This happens when a `.terraform.lock.hcl` left behind by a previous
`terraform init` is still present. OpenTofu honours it silently and keeps
pulling HashiCorp-hosted providers.

**Fix:**
```bash
cd lablink-infrastructure
tofu init -upgrade
# or, to regenerate from scratch:
rm .terraform.lock.hcl && tofu init
```

### Issue: Formatting differences
**Error:**
```
main.tf needs formatting
```

**Fix:**
```bash
tofu fmt -recursive lablink-infrastructure/
```

Claude can offer to run this automatically.

## What Gets Validated

**Formatting:**
- Indentation (2 spaces)
- Attribute alignment
- Blank lines between blocks
- Quote style consistency

**Syntax:**
- Resource type validity
- Argument names and types
- Required vs optional arguments
- Expression syntax
- Variable references
- Module configurations

**Configuration:**
- Provider requirements
- Resource dependencies
- Output references
- Local value usage
- Data source queries

## Pre-commit Integration

Add to `.git/hooks/pre-commit`:
```bash
#!/bin/bash
# Validate OpenTofu before commit
cd lablink-infrastructure
tofu fmt -check -recursive . || {
  echo "OpenTofu formatting issues found. Run: tofu fmt -recursive ."
  exit 1
}
tofu validate || {
  echo "OpenTofu validation failed. Fix errors before committing."
  exit 1
}
```

## CI Integration

This validation runs automatically in GitHub Actions via
`.github/workflows/terraform-deploy.yml`, from the `lablink-infrastructure`
working directory:
```yaml
- name: OpenTofu Format
  run: tofu fmt -check

- name: OpenTofu Validate
  run: tofu validate
```

Note the workflow filename and its `terraform:` job id are unchanged — the job
id is what branch-protection required-status-checks match on.

## Related Commands

- `/terraform-plan` - Preview infrastructure changes
- `/validate-yaml` - Validate configuration files
- `/validate-bash` - Validate shell scripts
