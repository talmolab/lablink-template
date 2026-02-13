#!/bin/bash
# Unified LabLink Setup Script
# Handles: Prerequisites, Configuration, OIDC, IAM, S3, DynamoDB, Route53, GitHub Secrets, config.yaml
#
# Usage: ./scripts/setup.sh
# Must be run from the repository root directory.

set -euo pipefail

# ============================================================================
# Colors and formatting
# ============================================================================
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m' # No Color

info()    { echo -e "${BLUE}ℹ${NC}  $*"; }
success() { echo -e "${GREEN}✅${NC} $*"; }
warn()    { echo -e "${YELLOW}⚠️${NC}  $*"; }
error()   { echo -e "${RED}❌${NC} $*"; }
header()  { echo -e "\n${BOLD}${CYAN}$*${NC}"; echo -e "${CYAN}$(printf '=%.0s' $(seq 1 ${#1}))${NC}"; }
prompt()  { echo -en "${BOLD}$*${NC}"; }

# ============================================================================
# Phase 1: Prerequisites Check
# ============================================================================
header "LabLink Unified Setup"
echo ""
echo "This script will set up everything you need to deploy LabLink:"
echo "  - AWS resources (OIDC, IAM role, S3, DynamoDB, Route53)"
echo "  - GitHub Actions secrets"
echo "  - Configuration file (config.yaml)"
echo ""

header "Phase 1: Prerequisites Check"

# Check: running from repo root
if [ ! -d "lablink-infrastructure" ]; then
    error "Must be run from the repository root (lablink-infrastructure/ directory not found)."
    echo "  cd /path/to/your/lablink-template && ./scripts/setup.sh"
    exit 1
fi
success "Running from repository root"

# Check: AWS CLI installed
if ! command -v aws &> /dev/null; then
    error "AWS CLI is not installed."
    echo "  Install: https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html"
    exit 1
fi
success "AWS CLI installed ($(aws --version 2>&1 | head -1))"

# Check: AWS credentials
if ! aws sts get-caller-identity &> /dev/null; then
    error "AWS credentials are not configured."
    echo "  Run: aws configure"
    echo "  Docs: https://docs.aws.amazon.com/cli/latest/userguide/cli-configure-quickstart.html"
    exit 1
fi
AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query 'Account' --output text)
AWS_CALLER_ARN=$(aws sts get-caller-identity --query 'Arn' --output text)
success "AWS authenticated (Account: ${AWS_ACCOUNT_ID}, Identity: ${AWS_CALLER_ARN})"

# Check: GitHub CLI installed
if ! command -v gh &> /dev/null; then
    error "GitHub CLI (gh) is not installed."
    echo "  Install: https://cli.github.com/"
    exit 1
fi
success "GitHub CLI installed ($(gh --version | head -1))"

# Check: GitHub CLI authenticated
if ! gh auth status &> /dev/null 2>&1; then
    error "GitHub CLI is not authenticated."
    echo "  Run: gh auth login"
    exit 1
fi
success "GitHub CLI authenticated"

# Check: openssl for password generation
if ! command -v openssl &> /dev/null; then
    warn "openssl not found — password auto-generation will use /dev/urandom fallback"
fi

# Auto-detect values
AUTO_REGION=$(aws configure get region 2>/dev/null || echo "")
GITHUB_REPO=$(gh repo view --json nameWithOwner -q '.nameWithOwner' 2>/dev/null || echo "")

if [ -n "$GITHUB_REPO" ]; then
    success "GitHub repo detected: ${GITHUB_REPO}"
else
    warn "Could not auto-detect GitHub repo. You'll be asked to enter it."
fi

if [ -n "$AUTO_REGION" ]; then
    success "AWS region detected: ${AUTO_REGION}"
fi

echo ""
success "All prerequisites passed!"

# ============================================================================
# Helper: prompt with default
# ============================================================================
ask() {
    local var_name="$1"
    local prompt_text="$2"
    local default="$3"
    local value

    if [ -n "$default" ]; then
        prompt "${prompt_text} [${default}]: "
    else
        prompt "${prompt_text}: "
    fi
    read -r value
    value="${value:-$default}"
    eval "$var_name=\"$value\""
}

ask_yes_no() {
    local var_name="$1"
    local prompt_text="$2"
    local default="$3"
    local value

    prompt "${prompt_text} [${default}]: "
    read -r value
    value="${value:-$default}"
    # Normalize to lowercase
    value=$(echo "$value" | tr '[:upper:]' '[:lower:]')
    if [[ "$value" == "y" || "$value" == "yes" ]]; then
        eval "$var_name=true"
    else
        eval "$var_name=false"
    fi
}

generate_password() {
    if command -v openssl &> /dev/null; then
        openssl rand -base64 16 | tr -d '/+=' | head -c 20
    else
        LC_ALL=C tr -dc 'A-Za-z0-9' < /dev/urandom | head -c 20
    fi
}

# ============================================================================
# Phase 2: Interactive Configuration Wizard
# ============================================================================
header "Phase 2: Configuration Wizard"
echo ""
echo "Answer the following prompts to configure your LabLink deployment."
echo "Press Enter to accept the default value shown in brackets."
echo ""

# --- Basic settings ---
echo -e "${BOLD}--- Basic Settings ---${NC}"

ask CFG_REGION "AWS Region" "${AUTO_REGION:-us-west-2}"

# Validate region
if ! aws ec2 describe-regions --region-names "$CFG_REGION" &> /dev/null 2>&1; then
    error "Invalid AWS region: ${CFG_REGION}"
    exit 1
fi

ask CFG_ENVIRONMENT "Environment (test/prod)" "test"
if [[ "$CFG_ENVIRONMENT" != "test" && "$CFG_ENVIRONMENT" != "prod" ]]; then
    warn "Unexpected environment '${CFG_ENVIRONMENT}'. Typical values: test, prod"
fi

# Derive a default org name from the GitHub repo
DEFAULT_ORG=""
if [ -n "$GITHUB_REPO" ]; then
    DEFAULT_ORG=$(echo "$GITHUB_REPO" | cut -d'/' -f1 | tr '[:upper:]' '[:lower:]')
fi

ask CFG_BUCKET "S3 bucket name (must be globally unique)" "tf-state-${DEFAULT_ORG:-myorg}-lablink"

# Check bucket name uniqueness (only if it doesn't exist yet)
if aws s3api head-bucket --bucket "$CFG_BUCKET" 2>/dev/null; then
    info "Bucket '${CFG_BUCKET}' already exists (will reuse)"
elif aws s3api head-bucket --bucket "$CFG_BUCKET" 2>&1 | grep -q "403"; then
    error "Bucket '${CFG_BUCKET}' exists but is owned by another AWS account. Choose a different name."
    exit 1
fi

# GitHub repo
if [ -z "$GITHUB_REPO" ]; then
    ask GITHUB_REPO "GitHub repository (org/repo)" ""
    if [ -z "$GITHUB_REPO" ]; then
        error "GitHub repository is required."
        exit 1
    fi
fi

echo ""
echo -e "${BOLD}--- DNS & SSL Settings ---${NC}"

ask_yes_no CFG_DNS_ENABLED "Enable custom domain? (y/N)" "N"

CFG_DOMAIN=""
CFG_DNS_PROVIDER="route53"
CFG_SSL_PROVIDER="none"
CFG_SSL_EMAIL=""
CFG_TERRAFORM_MANAGED="false"

if [ "$CFG_DNS_ENABLED" = "true" ]; then
    ask CFG_DOMAIN "Domain name (e.g., lablink.example.com)" ""
    if [ -z "$CFG_DOMAIN" ]; then
        error "Domain name is required when DNS is enabled."
        exit 1
    fi

    echo ""
    echo "  DNS Provider options:"
    echo "    1) route53   - AWS Route53 (this script will create hosted zone)"
    echo "    2) cloudflare - CloudFlare (you manage DNS in CloudFlare)"
    ask CFG_DNS_PROVIDER "DNS provider" "route53"

    if [ "$CFG_DNS_PROVIDER" = "route53" ]; then
        ask_yes_no CFG_TERRAFORM_MANAGED "Let Terraform manage DNS records? (y/N)" "y"
    fi

    echo ""
    echo "  SSL Provider options:"
    echo "    1) letsencrypt - Automatic SSL via Caddy (rate limits apply: 5 certs/domain/week)"
    echo "    2) cloudflare  - SSL via CloudFlare proxy"
    echo "    3) acm         - AWS Certificate Manager"
    echo "    4) none        - HTTP only (no SSL)"
    ask CFG_SSL_PROVIDER "SSL provider" "letsencrypt"

    if [ "$CFG_SSL_PROVIDER" = "letsencrypt" ]; then
        warn "Let's Encrypt rate limit: 5 certificates per exact domain per 7 days."
        warn "If you redeploy frequently, consider 'cloudflare' or 'none' for testing."
        ask CFG_SSL_EMAIL "Email for Let's Encrypt notifications" ""
    fi
fi

echo ""
echo -e "${BOLD}--- EC2 & Machine Settings ---${NC}"

echo "  Common GPU instance types:"
echo "    g4dn.xlarge  - NVIDIA T4 (good for ML, ~\$0.53/hr)"
echo "    g5.xlarge    - NVIDIA A10G (better GPU, ~\$1.01/hr)"
echo "    p3.2xlarge   - NVIDIA V100 (powerful, ~\$3.06/hr)"
echo "    t3.large     - CPU only (no GPU, ~\$0.08/hr)"
ask CFG_INSTANCE_TYPE "EC2 instance type" "g4dn.xlarge"

DEFAULT_AMI=""
if [ "$CFG_REGION" = "us-west-2" ]; then
    DEFAULT_AMI="ami-0601752c11b394251"
fi
ask CFG_AMI_ID "AMI ID (Ubuntu 24.04 with Docker+Nvidia)" "${DEFAULT_AMI}"
if [ -z "$CFG_AMI_ID" ]; then
    warn "No AMI ID provided. You will need to set this in config.yaml before deploying."
fi

ask CFG_DATA_REPO "Data repository URL (optional, press Enter to skip)" ""
ask CFG_SOFTWARE "Software name" "sleap"
ask CFG_EXTENSION "File extension" "slp"

echo ""
echo -e "${BOLD}--- EIP Settings ---${NC}"
echo "  persistent - Reuse the same Elastic IP across deployments"
echo "  dynamic    - Create a new Elastic IP each deployment"
ask CFG_EIP_STRATEGY "EIP strategy" "dynamic"

echo ""
echo -e "${BOLD}--- Passwords ---${NC}"

AUTO_ADMIN_PW=$(generate_password)
AUTO_DB_PW=$(generate_password)

echo "  Auto-generated passwords are available. Press Enter to use them,"
echo "  or type a custom password."
ask CFG_ADMIN_PASSWORD "Admin password" "$AUTO_ADMIN_PW"
ask CFG_DB_PASSWORD "Database password" "$AUTO_DB_PW"

# ============================================================================
# Phase 3: Summary + Confirm
# ============================================================================
header "Phase 3: Review Configuration"
echo ""
printf "  %-25s %s\n" "AWS Account:" "$AWS_ACCOUNT_ID"
printf "  %-25s %s\n" "AWS Region:" "$CFG_REGION"
printf "  %-25s %s\n" "GitHub Repo:" "$GITHUB_REPO"
printf "  %-25s %s\n" "Environment:" "$CFG_ENVIRONMENT"
printf "  %-25s %s\n" "S3 Bucket:" "$CFG_BUCKET"
printf "  %-25s %s\n" "Instance Type:" "$CFG_INSTANCE_TYPE"
printf "  %-25s %s\n" "AMI ID:" "${CFG_AMI_ID:-<not set>}"
printf "  %-25s %s\n" "Software:" "$CFG_SOFTWARE"
printf "  %-25s %s\n" "Extension:" "$CFG_EXTENSION"
printf "  %-25s %s\n" "Data Repo:" "${CFG_DATA_REPO:-<none>}"
printf "  %-25s %s\n" "EIP Strategy:" "$CFG_EIP_STRATEGY"

if [ "$CFG_DNS_ENABLED" = "true" ]; then
    printf "  %-25s %s\n" "DNS:" "Enabled"
    printf "  %-25s %s\n" "Domain:" "$CFG_DOMAIN"
    printf "  %-25s %s\n" "DNS Provider:" "$CFG_DNS_PROVIDER"
    printf "  %-25s %s\n" "Terraform-managed DNS:" "$CFG_TERRAFORM_MANAGED"
    printf "  %-25s %s\n" "SSL Provider:" "$CFG_SSL_PROVIDER"
    if [ -n "$CFG_SSL_EMAIL" ]; then
        printf "  %-25s %s\n" "SSL Email:" "$CFG_SSL_EMAIL"
    fi
else
    printf "  %-25s %s\n" "DNS:" "Disabled (IP-only)"
    printf "  %-25s %s\n" "SSL:" "None"
fi
echo ""

echo -e "${BOLD}Resources that will be created/configured:${NC}"
echo "  1. AWS OIDC Provider (for GitHub Actions)"
echo "  2. IAM Role: github-actions-lablink (with managed policies)"
echo "  3. S3 Bucket: ${CFG_BUCKET}"
echo "  4. DynamoDB Table: lock-table"
if [ "$CFG_DNS_ENABLED" = "true" ] && [ "$CFG_DNS_PROVIDER" = "route53" ]; then
    echo "  5. Route53 Hosted Zone for $(echo "$CFG_DOMAIN" | awk -F. '{if (NF>=2) print $(NF-1)"."$NF; else print $0}')"
fi
echo "  6. GitHub Secrets (AWS_ROLE_ARN, AWS_REGION, ADMIN_PASSWORD, DB_PASSWORD)"
echo "  7. Config file: lablink-infrastructure/config/config.yaml"
echo ""

prompt "Proceed with setup? [y/N]: "
read -r CONFIRM
if [[ "$CONFIRM" != "y" && "$CONFIRM" != "Y" ]]; then
    echo "Aborted."
    exit 0
fi

# ============================================================================
# Phase 4: Automated AWS + GitHub Setup
# ============================================================================
header "Phase 4: Creating Resources"

ROLE_NAME="github-actions-lablink"
OIDC_URL="token.actions.githubusercontent.com"
OIDC_PROVIDER_ARN="arn:aws:iam::${AWS_ACCOUNT_ID}:oidc-provider/${OIDC_URL}"

# Track what we've done for error reporting
COMPLETED_STEPS=()

# --- Step 1: OIDC Provider ---
echo ""
info "Step 1/7: OIDC Provider"

OIDC_EXISTS=false
if aws iam get-open-id-connect-provider --open-id-connect-provider-arn "$OIDC_PROVIDER_ARN" &> /dev/null 2>&1; then
    OIDC_EXISTS=true
fi

if [ "$OIDC_EXISTS" = "true" ]; then
    success "OIDC provider already exists: ${OIDC_PROVIDER_ARN}"
else
    info "Creating OIDC provider for GitHub Actions..."
    # Get the GitHub OIDC thumbprint
    THUMBPRINT="6938fd4d98bab03faadb97b34396831e3780aea1"

    aws iam create-open-id-connect-provider \
        --url "https://${OIDC_URL}" \
        --client-id-list "sts.amazonaws.com" \
        --thumbprint-list "$THUMBPRINT" \
        --output text > /dev/null
    success "Created OIDC provider"
fi
COMPLETED_STEPS+=("OIDC Provider")

# --- Step 2: IAM Role ---
echo ""
info "Step 2/7: IAM Role"

ROLE_ARN="arn:aws:iam::${AWS_ACCOUNT_ID}:role/${ROLE_NAME}"

if aws iam get-role --role-name "$ROLE_NAME" &> /dev/null 2>&1; then
    success "IAM role already exists: ${ROLE_NAME}"
    ROLE_ARN=$(aws iam get-role --role-name "$ROLE_NAME" --query 'Role.Arn' --output text)
else
    info "Creating IAM role: ${ROLE_NAME}..."

    TRUST_POLICY=$(cat <<TRUSTEOF
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Principal": {
                "Federated": "${OIDC_PROVIDER_ARN}"
            },
            "Action": "sts:AssumeRoleWithWebIdentity",
            "Condition": {
                "StringLike": {
                    "${OIDC_URL}:sub": "repo:${GITHUB_REPO}:*"
                },
                "StringEquals": {
                    "${OIDC_URL}:aud": "sts.amazonaws.com"
                }
            }
        }
    ]
}
TRUSTEOF
)

    ROLE_ARN=$(aws iam create-role \
        --role-name "$ROLE_NAME" \
        --assume-role-policy-document "$TRUST_POLICY" \
        --description "GitHub Actions role for LabLink deployment (${GITHUB_REPO})" \
        --query 'Role.Arn' \
        --output text)
    success "Created IAM role: ${ROLE_ARN}"

    # Attach managed policies
    POLICIES=(
        "arn:aws:iam::aws:policy/AmazonEC2FullAccess"
        "arn:aws:iam::aws:policy/AmazonS3FullAccess"
        "arn:aws:iam::aws:policy/IAMFullAccess"
        "arn:aws:iam::aws:policy/AmazonDynamoDBFullAccess"
        "arn:aws:iam::aws:policy/CloudWatchLogsFullAccess"
        "arn:aws:iam::aws:policy/AWSCloudTrail_FullAccess"
        "arn:aws:iam::aws:policy/AWSLambda_FullAccess"
        "arn:aws:iam::aws:policy/AmazonSNSFullAccess"
    )

    # Attach Route53 if DNS is enabled with Route53
    if [ "$CFG_DNS_ENABLED" = "true" ] && [ "$CFG_DNS_PROVIDER" = "route53" ]; then
        POLICIES+=("arn:aws:iam::aws:policy/AmazonRoute53FullAccess")
    fi

    for POLICY_ARN in "${POLICIES[@]}"; do
        POLICY_SHORT=$(echo "$POLICY_ARN" | awk -F'/' '{print $NF}')
        aws iam attach-role-policy \
            --role-name "$ROLE_NAME" \
            --policy-arn "$POLICY_ARN" 2>/dev/null || true
        success "  Attached: ${POLICY_SHORT}"
    done
fi
COMPLETED_STEPS+=("IAM Role")

# --- Step 3: S3 Bucket ---
echo ""
info "Step 3/7: S3 Bucket"

if aws s3api head-bucket --bucket "$CFG_BUCKET" 2>/dev/null; then
    success "S3 bucket already exists: ${CFG_BUCKET}"
else
    info "Creating S3 bucket: ${CFG_BUCKET}..."
    # us-east-1 doesn't support LocationConstraint
    if [ "$CFG_REGION" = "us-east-1" ]; then
        aws s3api create-bucket \
            --bucket "$CFG_BUCKET" \
            --region "$CFG_REGION" > /dev/null
    else
        aws s3api create-bucket \
            --bucket "$CFG_BUCKET" \
            --region "$CFG_REGION" \
            --create-bucket-configuration LocationConstraint="$CFG_REGION" > /dev/null
    fi

    aws s3api put-bucket-versioning \
        --bucket "$CFG_BUCKET" \
        --versioning-configuration Status=Enabled \
        --region "$CFG_REGION"
    success "Created S3 bucket with versioning: ${CFG_BUCKET}"
fi
COMPLETED_STEPS+=("S3 Bucket")

# --- Step 4: DynamoDB Table ---
echo ""
info "Step 4/7: DynamoDB Table"

if aws dynamodb describe-table --table-name lock-table --region "$CFG_REGION" &> /dev/null 2>&1; then
    success "DynamoDB table already exists: lock-table"
else
    info "Creating DynamoDB table: lock-table..."
    aws dynamodb create-table \
        --table-name lock-table \
        --attribute-definitions AttributeName=LockID,AttributeType=S \
        --key-schema AttributeName=LockID,KeyType=HASH \
        --billing-mode PAY_PER_REQUEST \
        --region "$CFG_REGION" > /dev/null
    success "Created DynamoDB table: lock-table"
fi
COMPLETED_STEPS+=("DynamoDB Table")

# --- Step 5: Route53 Hosted Zone ---
echo ""
info "Step 5/7: Route53 Hosted Zone"

CFG_ZONE_ID=""

if [ "$CFG_DNS_ENABLED" = "true" ] && [ "$CFG_DNS_PROVIDER" = "route53" ]; then
    # Extract root domain (e.g., example.com from test.example.com)
    ZONE_NAME=$(echo "$CFG_DOMAIN" | awk -F. '{if (NF>=2) print $(NF-1)"."$NF; else print $0}')

    EXISTING_ZONES=$(aws route53 list-hosted-zones-by-name \
        --dns-name "$ZONE_NAME" \
        --query "HostedZones[?Name=='${ZONE_NAME}.'].Id" \
        --output text 2>/dev/null || echo "")

    ZONE_COUNT=$(echo "$EXISTING_ZONES" | wc -w | tr -d ' ')

    if [ "$ZONE_COUNT" -eq 0 ] || [ -z "$EXISTING_ZONES" ]; then
        info "Creating Route53 hosted zone: ${ZONE_NAME}..."
        ZONE_OUTPUT=$(aws route53 create-hosted-zone \
            --name "$ZONE_NAME" \
            --caller-reference "lablink-setup-$(date +%s)" \
            --query 'HostedZone.Id' \
            --output text)
        CFG_ZONE_ID=$(echo "$ZONE_OUTPUT" | sed 's|/hostedzone/||')
        success "Created hosted zone: ${ZONE_NAME} (ID: ${CFG_ZONE_ID})"

        NS_RECORDS=$(aws route53 get-hosted-zone --id "$CFG_ZONE_ID" \
            --query 'DelegationSet.NameServers' \
            --output text)

        echo ""
        warn "IMPORTANT: Update your domain registrar with these nameservers:"
        echo "$NS_RECORDS" | tr '\t' '\n' | sed 's/^/    /'
        echo ""
    elif [ "$ZONE_COUNT" -eq 1 ]; then
        CFG_ZONE_ID=$(echo "$EXISTING_ZONES" | awk '{print $1}' | sed 's|/hostedzone/||')
        success "Found existing hosted zone: ${ZONE_NAME} (ID: ${CFG_ZONE_ID})"
    else
        error "Multiple hosted zones found for ${ZONE_NAME}."
        echo "  Please resolve this manually (delete duplicates or pick one)."
        echo "  Then re-run this script."
        echo ""
        echo "  Completed steps so far: ${COMPLETED_STEPS[*]}"
        exit 1
    fi
else
    info "DNS not using Route53 — skipping hosted zone creation"
fi
COMPLETED_STEPS+=("Route53")

# --- Step 6: GitHub Secrets ---
echo ""
info "Step 6/7: GitHub Secrets"

info "Setting AWS_ROLE_ARN..."
echo "$ROLE_ARN" | gh secret set AWS_ROLE_ARN --repo "$GITHUB_REPO"
success "Set AWS_ROLE_ARN"

info "Setting AWS_REGION..."
echo "$CFG_REGION" | gh secret set AWS_REGION --repo "$GITHUB_REPO"
success "Set AWS_REGION"

info "Setting ADMIN_PASSWORD..."
echo "$CFG_ADMIN_PASSWORD" | gh secret set ADMIN_PASSWORD --repo "$GITHUB_REPO"
success "Set ADMIN_PASSWORD"

info "Setting DB_PASSWORD..."
echo "$CFG_DB_PASSWORD" | gh secret set DB_PASSWORD --repo "$GITHUB_REPO"
success "Set DB_PASSWORD"

COMPLETED_STEPS+=("GitHub Secrets")

# --- Step 7: Generate config.yaml ---
echo ""
info "Step 7/7: Generating config.yaml"

CONFIG_FILE="lablink-infrastructure/config/config.yaml"

# Build the allocator image tag based on environment
if [ "$CFG_ENVIRONMENT" = "prod" ]; then
    ALLOCATOR_TAG="linux-amd64-latest"
else
    ALLOCATOR_TAG="linux-amd64-latest-test"
fi

cat > "$CONFIG_FILE" <<CONFIGEOF
# LabLink Configuration
# Generated by setup.sh on $(date -u +"%Y-%m-%dT%H:%M:%SZ")
# Environment: ${CFG_ENVIRONMENT}

db:
  dbname: "lablink_db"
  user: "lablink"
  password: "PLACEHOLDER_DB_PASSWORD"  # Injected from GitHub secret at deploy time
  host: "localhost"
  port: 5432
  table_name: "vms"
  message_channel: "vm_updates"

machine:
  machine_type: "${CFG_INSTANCE_TYPE}"
  image: "ghcr.io/talmolab/lablink-client-base-image:${ALLOCATOR_TAG}"
  ami_id: "${CFG_AMI_ID}"
  repository: "${CFG_DATA_REPO}"
  software: "${CFG_SOFTWARE}"
  extension: "${CFG_EXTENSION}"

allocator:
  image_tag: "${ALLOCATOR_TAG}"

app:
  admin_user: "admin"
  admin_password: "PLACEHOLDER_ADMIN_PASSWORD"  # Injected from GitHub secret at deploy time
  region: "${CFG_REGION}"

dns:
  enabled: ${CFG_DNS_ENABLED}
  terraform_managed: ${CFG_TERRAFORM_MANAGED}
  domain: "${CFG_DOMAIN}"
  zone_id: "${CFG_ZONE_ID}"

eip:
  strategy: "${CFG_EIP_STRATEGY}"
  tag_name: "lablink-eip"

ssl:
  provider: "${CFG_SSL_PROVIDER}"
  email: "${CFG_SSL_EMAIL}"
  certificate_arn: ""

startup_script:
  enabled: false
  path: ""
  on_error: "continue"

monitoring:
  enabled: false
  email: ""
  thresholds:
    max_instances_per_5min: 10
    max_terminations_per_5min: 20
    max_unauthorized_calls_per_15min: 5
  budget:
    enabled: false
    monthly_budget_usd: 500
  cloudtrail:
    retention_days: 90

bucket_name: "${CFG_BUCKET}"
CONFIGEOF

success "Generated ${CONFIG_FILE}"
COMPLETED_STEPS+=("config.yaml")

# ============================================================================
# Phase 5: Verification & Next Steps
# ============================================================================
header "Phase 5: Verification"

VERIFY_PASS=true

# Verify S3 bucket
if aws s3api head-bucket --bucket "$CFG_BUCKET" 2>/dev/null; then
    success "S3 bucket exists: ${CFG_BUCKET}"
else
    error "S3 bucket NOT found: ${CFG_BUCKET}"
    VERIFY_PASS=false
fi

# Verify DynamoDB table
if aws dynamodb describe-table --table-name lock-table --region "$CFG_REGION" &> /dev/null 2>&1; then
    success "DynamoDB table exists: lock-table"
else
    error "DynamoDB table NOT found: lock-table"
    VERIFY_PASS=false
fi

# Verify IAM role
if aws iam get-role --role-name "$ROLE_NAME" &> /dev/null 2>&1; then
    success "IAM role exists: ${ROLE_NAME}"
else
    error "IAM role NOT found: ${ROLE_NAME}"
    VERIFY_PASS=false
fi

# Verify OIDC provider
if aws iam get-open-id-connect-provider --open-id-connect-provider-arn "$OIDC_PROVIDER_ARN" &> /dev/null 2>&1; then
    success "OIDC provider exists"
else
    error "OIDC provider NOT found"
    VERIFY_PASS=false
fi

# Verify GitHub secrets
SECRET_LIST=$(gh secret list --repo "$GITHUB_REPO" 2>/dev/null || echo "")
for SECRET_NAME in AWS_ROLE_ARN AWS_REGION ADMIN_PASSWORD DB_PASSWORD; do
    if echo "$SECRET_LIST" | grep -q "$SECRET_NAME"; then
        success "GitHub secret set: ${SECRET_NAME}"
    else
        error "GitHub secret NOT found: ${SECRET_NAME}"
        VERIFY_PASS=false
    fi
done

# Verify config file exists
if [ -f "$CONFIG_FILE" ]; then
    success "Config file exists: ${CONFIG_FILE}"
else
    error "Config file NOT found: ${CONFIG_FILE}"
    VERIFY_PASS=false
fi

echo ""
if [ "$VERIFY_PASS" = "true" ]; then
    success "All verifications passed!"
else
    warn "Some verifications failed. Review the errors above."
fi

# ============================================================================
# Next Steps
# ============================================================================
header "Setup Complete!"
echo ""
echo -e "${BOLD}Passwords (save these now — they won't be shown again):${NC}"
echo -e "  Admin password: ${YELLOW}${CFG_ADMIN_PASSWORD}${NC}"
echo -e "  DB password:    ${YELLOW}${CFG_DB_PASSWORD}${NC}"
echo ""

echo -e "${BOLD}Next steps:${NC}"
echo ""
echo "  1. Review the generated config:"
echo "     ${CONFIG_FILE}"
echo ""
echo "  2. Commit and push:"
echo "     git add lablink-infrastructure/config/config.yaml"
echo "     git commit -m \"Add LabLink configuration\""
echo "     git push"
echo ""
echo "  3. Deploy via GitHub Actions:"
echo "     Go to Actions → 'Deploy LabLink Infrastructure' → Run workflow"
echo "     Select environment: ${CFG_ENVIRONMENT}"
echo ""

if [ "$CFG_DNS_ENABLED" = "true" ] && [ "$CFG_DNS_PROVIDER" = "route53" ]; then
    echo "  4. (DNS) Update your domain registrar's nameservers to point to Route53"
    echo "     Then wait for DNS propagation (usually minutes, up to 48 hours)"
    echo ""
fi

echo "  For help: see README.md or https://talmolab.github.io/lablink/"
echo ""
