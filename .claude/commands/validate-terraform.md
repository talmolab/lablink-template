# Validate Terraform Code

Validate Terraform formatting and syntax for lablink-infrastructure code.

## Command

```bash
# Check formatting (no changes made)
terraform fmt -check -recursive lablink-infrastructure/

# Validate syntax and configuration
cd lablink-infrastructure
terraform init -backend=false
terraform validate
```

## What This Command Does

Claude will:
1. Check all `.tf` files for proper formatting using `terraform fmt -check`
2. Initialize Terraform without backend configuration
3. Run `terraform validate` to check syntax and configuration
4. Report any errors with file:line references
5. Provide fix suggestions for common issues

## Usage

Simply ask Claude:
```
Validate Terraform code in lablink-infrastructure
```

Or use the validation command before committing:
```
Run /validate-terraform before I commit these changes
```

## Expected Output

### Success
```
✓ Terraform formatting is correct (all .tf files)
✓ Terraform configuration is valid
  - 15 resources defined
  - 3 data sources
  - 5 outputs
  - No errors found
```

### Formatting Issues
```
✗ Terraform formatting issues found:

lablink-infrastructure/main.tf
  - Line 45: Incorrect indentation (expected 2 spaces)
  - Line 78: Missing blank line between resources

Fix with: terraform fmt lablink-infrastructure/
```

### Syntax Errors
```
✗ Terraform validation failed:

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
terraform init
```

### Issue: "Provider not found"
**Error:**
```
Error: Could not load plugin
```

**Fix:**
```bash
cd lablink-infrastructure
terraform init -upgrade
```

### Issue: Formatting differences
**Error:**
```
main.tf needs formatting
```

**Fix:**
```bash
terraform fmt -recursive lablink-infrastructure/
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
# Validate Terraform before commit
cd lablink-infrastructure
terraform fmt -check -recursive . || {
  echo "Terraform formatting issues found. Run: terraform fmt -recursive ."
  exit 1
}
terraform validate || {
  echo "Terraform validation failed. Fix errors before committing."
  exit 1
}
```

## CI Integration

This validation runs automatically in GitHub Actions via `.github/workflows/terraform-deploy.yml`:
```yaml
- name: Terraform Format Check
  run: terraform fmt -check -recursive lablink-infrastructure/

- name: Terraform Validate
  run: |
    cd lablink-infrastructure
    terraform init -backend=false
    terraform validate
```

## Related Commands

- `/terraform-plan` - Preview infrastructure changes
- `/terraform-apply` - Apply validated changes
- `/validate-yaml` - Validate configuration files
- `/validate-bash` - Validate shell scripts