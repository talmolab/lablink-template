# Validate Bash Scripts

Check shell scripts for common errors and best practices using ShellCheck.

## Command

```bash
# Validate all shell scripts
find lablink-infrastructure -name "*.sh" -type f -exec shellcheck {} +

# Validate specific script
shellcheck lablink-infrastructure/user_data.sh

# Validate with specific severity level
shellcheck --severity=warning lablink-infrastructure/user_data.sh
```

## What This Command Does

Claude will:
1. Run `shellcheck` on all `.sh` files
2. Report findings by severity (error, warning, info, style)
3. Provide fix examples for common issues
4. Link to ShellCheck wiki for detailed explanations
5. Suggest best practices for shell scripting

## Usage

Simply ask Claude:
```
Validate all bash scripts
```

Or validate specific scripts:
```
Check lablink-infrastructure/user_data.sh for shellcheck issues
```

## Expected Output

### Success
```
✓ All shell scripts passed shellcheck validation

Validated files:
  - lablink-infrastructure/user_data.sh (0 issues)
  - lablink-infrastructure/scripts/init-terraform.sh (0 issues)

No issues found.
```

### With Issues
```
✗ ShellCheck found 3 issues:

In lablink-infrastructure/user_data.sh line 45:
sudo systemctl start $SERVICE_NAME
                      ^----------^ SC2086 (info): Double quote to prevent globbing and word splitting.

Did you mean:
sudo systemctl start "$SERVICE_NAME"

In lablink-infrastructure/user_data.sh line 78:
cd /var/log
^-- SC2164 (warning): Use 'cd ... || exit' in case cd fails.

For more information:
  https://www.shellcheck.net/wiki/SC2086 -- Double quote to prevent globbing...
  https://www.shellcheck.net/wiki/SC2164 -- Use 'cd ... || exit' in case cd...
```

## Severity Levels

**Error (most severe):**
- Syntax errors that prevent script execution
- Critical bugs that will cause script to fail
- Example: Undefined variables, missing quotes causing command failures

**Warning:**
- Issues that may cause unexpected behavior
- Best practice violations
- Example: Unquoted variables, risky cd commands

**Info:**
- Minor improvements suggested
- Optional but recommended fixes
- Example: Quote variables to prevent globbing

**Style:**
- Stylistic improvements
- Cosmetic issues
- Example: Prefer `$(...)` over backticks

## Common Issues & Fixes

### Issue: SC2086 - Unquoted variable
**ShellCheck:**
```
SC2086: Double quote to prevent globbing and word splitting.
```

**Before:**
```bash
docker run $IMAGE_NAME
```

**After:**
```bash
docker run "$IMAGE_NAME"
```

### Issue: SC2164 - cd without error checking
**ShellCheck:**
```
SC2164: Use 'cd ... || exit' in case cd fails.
```

**Before:**
```bash
cd /some/directory
./script.sh
```

**After:**
```bash
cd /some/directory || exit 1
./script.sh
```

### Issue: SC2155 - Declare and assign separately
**ShellCheck:**
```
SC2155: Declare and assign separately to avoid masking return values.
```

**Before:**
```bash
local result=$(some_command)
```

**After:**
```bash
local result
result=$(some_command)
```

### Issue: SC2046 - Quote to prevent word splitting
**ShellCheck:**
```
SC2046: Quote this to prevent word splitting.
```

**Before:**
```bash
for file in $(ls *.txt); do
  echo "$file"
done
```

**After:**
```bash
for file in *.txt; do
  echo "$file"
done
```

### Issue: SC2034 - Unused variable
**ShellCheck:**
```
SC2034: FOO appears unused. Verify use (or export if used externally).
```

**Fix:** Remove unused variable or export it if needed:
```bash
export FOO="value"  # If used by child processes
```

## Installation

Install ShellCheck:

**macOS:**
```bash
brew install shellcheck
```

**Ubuntu/Debian:**
```bash
apt-get install shellcheck
```

**From source:**
```bash
# Latest release
wget https://github.com/koalaman/shellcheck/releases/download/stable/shellcheck-stable.linux.x86_64.tar.xz
tar -xf shellcheck-stable.linux.x86_64.tar.xz
sudo cp shellcheck-stable/shellcheck /usr/local/bin/
```

**Docker (no installation):**
```bash
docker run --rm -v "$PWD:/mnt" koalaman/shellcheck:stable lablink-infrastructure/user_data.sh
```

## Best Practices

**Always use in scripts:**
```bash
#!/bin/bash
set -euo pipefail  # Exit on error, undefined vars, pipe failures
```

**Quote variables:**
```bash
# Good
echo "$VAR"
cd "$DIR" || exit 1

# Bad
echo $VAR
cd $DIR
```

**Use `[[` instead of `[` for conditionals:**
```bash
# Good
if [[ -f "$FILE" ]]; then
  echo "File exists"
fi

# Less robust
if [ -f $FILE ]; then
  echo "File exists"
fi
```

**Check command success:**
```bash
# Good
if some_command; then
  echo "Success"
else
  echo "Failed"
  exit 1
fi

# Bad
some_command  # No error checking
```

## CI Integration

ShellCheck runs in GitHub Actions:

```yaml
name: Validate Scripts

on: [pull_request]

jobs:
  shellcheck:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - name: Run ShellCheck
        uses: ludeeus/action-shellcheck@master
        with:
          scandir: './lablink-infrastructure'
          severity: warning
```

## Ignoring Warnings

If you need to ignore specific warnings:

```bash
# Inline disable
# shellcheck disable=SC2086
docker run $IMAGE_NAME  # Intentionally unquoted

# Disable for whole file
# shellcheck disable=SC2086,SC2164
```

**Only ignore warnings when you have a good reason!**

## Related Commands

- `/validate-terraform` - Validate Terraform code
- `/validate-yaml` - Validate configuration files
- `/review-pr` - Comprehensive PR review (includes shellcheck)