#!/bin/bash
# LabLink Preflight Doctor
#
# Re-runnable health check for a configured template repo. Answers "would a
# deploy work right now?" in seconds, locally, instead of after a push.
#
# It re-checks the resources setup.sh created (they can be deleted out of band)
# and reproduces every hard-fail in .github/workflows/terraform-deploy.yml, so
# a config problem surfaces here rather than three minutes into a workflow run.
#
# Usage: ./scripts/doctor.sh
# Runs from any directory: it resolves the repository from its own path.
#
# Prerequisites: aws CLI, gh CLI. docker is needed only for the schema check,
# tofu only if you plan to run `tofu plan` locally; both are WARN if absent.
#
# Exit status: 0 if every check passed or warned, 1 if any check failed.
#
# Environment variables:
#   NO_COLOR   Set to any value to disable colored output

# No `set -e` on purpose: a doctor must report every failing check, not abort on
# the first one. Failures are counted in FAILED and drive the exit status instead.
set -uo pipefail

# Colors (respects NO_COLOR, same convention as cleanup-orphaned-resources.sh)
if [ -z "${NO_COLOR:-}" ] && [ -t 1 ]; then
    RED='\033[0;31m'
    GREEN='\033[0;32m'
    YELLOW='\033[1;33m'
    BLUE='\033[0;34m'
    BOLD='\033[1m'
    DIM='\033[2m'
    NC='\033[0m'
else
    RED='' GREEN='' YELLOW='' BLUE='' BOLD='' DIM='' NC=''
fi

CONFIG_FILE="lablink-infrastructure/config/config.yaml"
ROLE_NAME="github-actions-lablink"
OIDC_URL="token.actions.githubusercontent.com"
LOCK_TABLE="lock-table"

FAILED=0
WARNED=0

header() { echo ""; echo -e "${BOLD}${BLUE}$*${NC}"; }
pass()   { echo -e "  ${GREEN}PASS${NC}  $1"; }
fail()   { echo -e "  ${RED}FAIL${NC}  $1"; [ -n "${2:-}" ] && echo -e "        ${DIM}$2${NC}"; FAILED=$((FAILED + 1)); }
warn()   { echo -e "  ${YELLOW}WARN${NC}  $1"; [ -n "${2:-}" ] && echo -e "        ${DIM}$2${NC}"; WARNED=$((WARNED + 1)); }

# ============================================================================
# Work from the repository root no matter where the caller is: every path below is
# relative to it, including the docker mount for the schema check. This script takes
# no arguments, so there is no caller-relative path to invalidate.
# ============================================================================
cd "$(dirname "${BASH_SOURCE[0]}")/.." || exit 1

if [ ! -d "lablink-infrastructure" ]; then
    echo -e "${RED}Error:${NC} lablink-infrastructure/ not found next to scripts/."
    echo "  Is this a complete lablink-template checkout? Expected it at $(pwd)."
    exit 1
fi

echo -e "${BOLD}LabLink Doctor${NC} — checking whether a deploy would work right now."

# ============================================================================
# Config file
#
# Checked first: the AWS and GitHub checks below read bucket_name and region
# out of it, so a missing config makes them unanswerable rather than failing.
# ============================================================================
header "Configuration"

CFG_BUCKET=""
CFG_REGION=""

if [ ! -f "$CONFIG_FILE" ]; then
    fail "$CONFIG_FILE not found" "Run ./scripts/setup.sh (first time) or ./scripts/configure.sh."
else
    pass "$CONFIG_FILE exists"

    # The deploy workflow's "Inject Password Secrets" step exits 1 on each of
    # the next four checks. Catch them here instead.
    for key in deployment_name environment; do
        if grep -qE "^${key}:" "$CONFIG_FILE"; then
            pass "top-level '${key}:' present  $(grep -m1 -E "^${key}:" "$CONFIG_FILE" | sed 's/^[^:]*: *//')"
        else
            fail "no top-level '${key}:' in config" "The deploy workflow pins this field and exits if it is absent. Regenerate with ./scripts/configure.sh."
        fi
    done

    for placeholder in PLACEHOLDER_ADMIN_PASSWORD PLACEHOLDER_DB_PASSWORD; do
        if grep -q "$placeholder" "$CONFIG_FILE"; then
            pass "$placeholder present for substitution"
        else
            fail "$placeholder missing from config" "The workflow substitutes it from a GitHub secret and exits if it is absent. Regenerate with ./scripts/configure.sh."
        fi
    done

    # MISSING is the allocator's unresolved-secret sentinel. admin_user is never
    # substituted by the workflow, so a MISSING there survives a green deploy
    # and stops the allocator from starting.
    MISSING_RE='^[[:space:]]*(admin_user|admin_password|password):[[:space:]]*"?MISSING"?[[:space:]]*$'
    if grep -qE "$MISSING_RE" "$CONFIG_FILE"; then
        fail "config leaves a credential unresolved (MISSING)" "$(grep -nE "$MISSING_RE" "$CONFIG_FILE" | tr '\n' ' ')"
    else
        pass "no unresolved MISSING credentials"
    fi

    IMAGE_TAG=$(grep -A5 "^allocator:" "$CONFIG_FILE" | grep "image_tag:" | awk '{print $2}' | tr -d '"')
    if [ -n "$IMAGE_TAG" ]; then
        pass "allocator.image_tag: $IMAGE_TAG"
    else
        fail "allocator.image_tag not set" "The workflow reads it to pick the validation image and exits if it is absent."
    fi

    CFG_BUCKET=$(grep "^bucket_name:" "$CONFIG_FILE" | awk '{print $2}' | tr -d '"' | head -n 1)
    if [ -n "$CFG_BUCKET" ] && [ "$CFG_BUCKET" != "YOUR-UNIQUE-SUFFIX" ]; then
        pass "bucket_name: $CFG_BUCKET"
    else
        fail "bucket_name not set to a real value" "init-terraform.sh refuses to init without it."
    fi

    CFG_REGION=$(grep -A 5 "^app:" "$CONFIG_FILE" | grep "^  region:" | awk '{print $2}' | tr -d '"' | head -n 1)
    if [ -n "$CFG_REGION" ]; then
        pass "app.region: $CFG_REGION"
    else
        fail "app.region not set" "init-terraform.sh refuses to init without it."
    fi
fi

# ============================================================================
# Tools
# ============================================================================
header "Tools"

if command -v aws &> /dev/null; then
    pass "aws  $(aws --version 2>&1 | awk '{print $1}')"
else
    fail "aws CLI not found" "Install: https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html"
fi

if command -v gh &> /dev/null; then
    if gh auth status &> /dev/null; then
        pass "gh   authenticated"
    else
        fail "gh is installed but not authenticated" "Run: gh auth login"
    fi
else
    fail "gh CLI not found" "Install: https://cli.github.com/"
fi

# Schema validation runs the allocator image, so docker is only as necessary as
# that one check. Path B deploys from Actions, which brings its own docker.
HAVE_DOCKER=false
if command -v docker &> /dev/null && docker info &> /dev/null; then
    HAVE_DOCKER=true
    pass "docker  daemon reachable"
else
    warn "docker unavailable — skipping config schema validation" "The deploy workflow still validates before applying; this only moves the check earlier."
fi

# tofu is optional for Path B: the deploy workflow installs its own. It matters
# only for a local `tofu plan`. The 1.10 floor is not cosmetic — see the
# rationale in lablink-infrastructure/backend.tf.
if command -v tofu &> /dev/null; then
    TOFU_VERSION=$(tofu version -json 2>/dev/null | grep -m1 '"terraform_version"' | sed 's/.*: *"\([^"]*\)".*/\1/')
    TOFU_MAJOR=${TOFU_VERSION%%.*}
    TOFU_REST=${TOFU_VERSION#*.}
    TOFU_MINOR=${TOFU_REST%%.*}
    if [ -z "$TOFU_VERSION" ]; then
        warn "tofu found but version unreadable"
    elif [ "$TOFU_MAJOR" -gt 1 ] 2>/dev/null || { [ "$TOFU_MAJOR" -eq 1 ] && [ "$TOFU_MINOR" -ge 10 ]; } 2>/dev/null; then
        pass "tofu v$TOFU_VERSION"
    else
        fail "tofu v$TOFU_VERSION is below the 1.10.0 floor" "Older releases vendor an aws-sdk-go-v2 that corrupts S3 state on upload retries. See lablink-infrastructure/backend.tf."
    fi
else
    warn "tofu not found — only needed for a local 'tofu plan'" "The deploy workflow installs its own."
fi

# ============================================================================
# AWS — the resources setup.sh created, re-checked because they can be
# deleted out of band long after setup succeeded
# ============================================================================
header "AWS"

if ! command -v aws &> /dev/null; then
    warn "skipped — aws CLI not available"
elif ! IDENTITY=$(aws sts get-caller-identity --output text --query '[Account,Arn]' 2>&1); then
    fail "AWS credentials invalid or expired" "Run 'aws configure' or 'aws sso login'. Detail: $(echo "$IDENTITY" | grep -v '^[[:space:]]*$' | head -1)"
else
    pass "credentials  account $(echo "$IDENTITY" | awk '{print $1}'), $(echo "$IDENTITY" | awk '{print $2}')"

    if [ -n "$CFG_BUCKET" ]; then
        if aws s3api head-bucket --bucket "$CFG_BUCKET" 2>/dev/null; then
            pass "S3 state bucket exists: $CFG_BUCKET"
        else
            fail "S3 state bucket not found: $CFG_BUCKET" "Re-run ./scripts/setup.sh to recreate it."
        fi
    else
        warn "S3 state bucket check skipped — no bucket_name in config"
    fi

    if [ -n "$CFG_REGION" ]; then
        if aws dynamodb describe-table --table-name "$LOCK_TABLE" --region "$CFG_REGION" &> /dev/null; then
            pass "DynamoDB lock table exists: $LOCK_TABLE ($CFG_REGION)"
        else
            fail "DynamoDB lock table not found: $LOCK_TABLE in $CFG_REGION" "backend-*.hcl hardcodes this name. Re-run ./scripts/setup.sh."
        fi
    else
        warn "DynamoDB lock table check skipped — no app.region in config"
    fi

    if aws iam get-role --role-name "$ROLE_NAME" &> /dev/null; then
        pass "IAM role exists: $ROLE_NAME"
    else
        fail "IAM role not found: $ROLE_NAME" "GitHub Actions assumes it via OIDC. Re-run ./scripts/setup.sh."
    fi

    AWS_ACCOUNT_ID=$(echo "$IDENTITY" | awk '{print $1}')
    if aws iam get-open-id-connect-provider \
        --open-id-connect-provider-arn "arn:aws:iam::${AWS_ACCOUNT_ID}:oidc-provider/${OIDC_URL}" &> /dev/null; then
        pass "OIDC provider exists: $OIDC_URL"
    else
        fail "OIDC provider not found: $OIDC_URL" "Without it GitHub Actions cannot assume $ROLE_NAME. Re-run ./scripts/setup.sh."
    fi
fi

# ============================================================================
# GitHub secrets
#
# Only existence is checkable — secret values are write-only. A wrong-but-set
# AWS_ROLE_ARN still fails at deploy time.
# ============================================================================
header "GitHub secrets"

if ! command -v gh &> /dev/null || ! gh auth status &> /dev/null; then
    warn "skipped — gh CLI unavailable or not authenticated"
else
    GITHUB_REPO=$(gh repo view --json nameWithOwner -q '.nameWithOwner' 2>/dev/null || echo "")
    if [ -z "$GITHUB_REPO" ]; then
        warn "could not determine the GitHub repository" "Is this a clone with a GitHub remote?"
    else
        SECRET_LIST=$(gh secret list --repo "$GITHUB_REPO" 2>/dev/null || echo "")
        for SECRET_NAME in AWS_ROLE_ARN AWS_REGION ADMIN_PASSWORD DB_PASSWORD; do
            if echo "$SECRET_LIST" | grep -q "^${SECRET_NAME}\b"; then
                pass "$SECRET_NAME set on $GITHUB_REPO"
            else
                fail "$SECRET_NAME not set on $GITHUB_REPO" "Re-run ./scripts/setup.sh, or: gh secret set $SECRET_NAME --repo $GITHUB_REPO"
            fi
        done
    fi
fi

# ============================================================================
# Config schema
#
# The allocator's schema is strict: any key not in its structured config makes
# the config fail outright. Run the same validator the deploy workflow runs.
# ============================================================================
header "Config schema"

if [ ! -f "$CONFIG_FILE" ]; then
    warn "skipped — no config file"
elif [ "$HAVE_DOCKER" != "true" ]; then
    warn "skipped — docker unavailable"
elif [ -z "${IMAGE_TAG:-}" ]; then
    warn "skipped — no allocator.image_tag to pick a validation image"
else
    ALLOCATOR_IMAGE="ghcr.io/talmolab/lablink-allocator-image:${IMAGE_TAG}"
    if ! docker image inspect "$ALLOCATOR_IMAGE" &> /dev/null; then
        echo -e "  ${DIM}pulling $ALLOCATOR_IMAGE...${NC}"
        if ! docker pull --quiet "$ALLOCATOR_IMAGE" &> /dev/null; then
            warn "could not pull $ALLOCATOR_IMAGE" "Check the tag, or 'docker login ghcr.io' if the image is private."
            ALLOCATOR_IMAGE=""
        fi
    fi

    if [ -n "$ALLOCATOR_IMAGE" ]; then
        if VALIDATE_OUT=$(docker run --rm \
            -v "$(pwd)/${CONFIG_FILE}:/config/config.yaml:ro" \
            "$ALLOCATOR_IMAGE" \
            uv run lablink-validate-config /config/config.yaml --verbose 2>&1); then
            pass "config validates against the allocator schema"
        else
            fail "config failed schema validation" "$(echo "$VALIDATE_OUT" | tail -5 | tr '\n' ' ')"
        fi
    fi
fi

# ============================================================================
# Summary
# ============================================================================
echo ""
if [ "$FAILED" -gt 0 ]; then
    echo -e "${RED}${BOLD}${FAILED} check(s) failed${NC}${WARNED:+, ${WARNED} warned}. Fix the failures above before deploying."
    exit 1
fi

if [ "$WARNED" -gt 0 ]; then
    echo -e "${GREEN}${BOLD}All checks passed${NC} (${WARNED} warned). Ready to deploy."
else
    echo -e "${GREEN}${BOLD}All checks passed.${NC} Ready to deploy."
fi
echo -e "${DIM}Deploy: Actions -> Deploy LabLink Infrastructure -> Run workflow${NC}"
