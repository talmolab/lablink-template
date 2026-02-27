#!/bin/bash
# LabLink Infrastructure Cost Estimator
# Reads config.yaml and queries the AWS Pricing API for a monthly cost breakdown.
#
# Usage: ./scripts/estimate-costs.sh
# Must be run from the repository root directory.
#
# Prerequisites: aws CLI, jq
# Uses the caller's AWS credentials (not the EC2 instance role).

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
DIM='\033[2m'
NC='\033[0m' # No Color

info()    { echo -e "${BLUE}i${NC}  $*"; }
success() { echo -e "${GREEN}OK${NC} $*"; }
warn()    { echo -e "${YELLOW}!!${NC}  $*"; }
error()   { echo -e "${RED}ERR${NC} $*"; }

# ============================================================================
# Prerequisites
# ============================================================================
if [ ! -d "lablink-infrastructure" ]; then
    error "Must be run from the repository root (lablink-infrastructure/ directory not found)."
    echo "  cd /path/to/your/lablink-template && ./scripts/estimate-costs.sh"
    exit 1
fi

CONFIG_FILE="lablink-infrastructure/config/config.yaml"

if [ ! -f "$CONFIG_FILE" ]; then
    error "Config file not found: $CONFIG_FILE"
    echo "  Run ./scripts/configure.sh first to create your configuration."
    exit 1
fi

# Check for jq
if ! command -v jq &>/dev/null; then
    error "jq is required but not installed."
    echo "  Install it with:"
    echo "    macOS:  brew install jq"
    echo "    Ubuntu: sudo apt-get install jq"
    exit 1
fi

# Check for AWS CLI — if missing, we fall back to hardcoded estimates
USE_LIVE_PRICING=true
if ! command -v aws &>/dev/null; then
    warn "AWS CLI not found. Using hardcoded price estimates (may not reflect current pricing)."
    USE_LIVE_PRICING=false
fi

# ============================================================================
# Config reader (same pattern as configure.sh)
# ============================================================================
cfg_get() {
    local key="$1"
    local fallback="${2:-}"

    local value=""
    case "$key" in
        app.region)
            value=$(awk '/^app:/{found=1} found && /region:/{print $2; exit}' "$CONFIG_FILE" 2>/dev/null | tr -d '"' || true)
            ;;
        machine.machine_type)
            value=$(awk '/^machine:/{found=1} found && /machine_type:/{print $2; exit}' "$CONFIG_FILE" 2>/dev/null | tr -d '"' || true)
            ;;
        eip.strategy)
            value=$(awk '/^eip:/{found=1} found && /strategy:/{print $2; exit}' "$CONFIG_FILE" 2>/dev/null | tr -d '"' || true)
            ;;
        ssl.provider)
            value=$(awk '/^ssl:/{found=1} found && /provider:/{print $2; exit}' "$CONFIG_FILE" 2>/dev/null | tr -d '"' || true)
            ;;
        dns.enabled)
            value=$(awk '/^dns:/{found=1} found && /enabled:/{print $2; exit}' "$CONFIG_FILE" 2>/dev/null | tr -d '"' || true)
            ;;
        monitoring.enabled)
            value=$(awk '/^monitoring:/{found=1} found && /^  enabled:/{print $2; exit}' "$CONFIG_FILE" 2>/dev/null | tr -d '"' || true)
            ;;
        *)
            value=""
            ;;
    esac

    value=$(echo "$value" | sed 's/ *#.*//' | xargs 2>/dev/null || true)
    if [ -n "$value" ]; then
        echo "$value"
    else
        echo "$fallback"
    fi
}

# ============================================================================
# Region code → Pricing API location name
# ============================================================================
region_to_name() {
    case "$1" in
        us-east-1)      echo "US East (N. Virginia)" ;;
        us-east-2)      echo "US East (Ohio)" ;;
        us-west-1)      echo "US West (N. California)" ;;
        us-west-2)      echo "US West (Oregon)" ;;
        af-south-1)     echo "Africa (Cape Town)" ;;
        ap-east-1)      echo "Asia Pacific (Hong Kong)" ;;
        ap-south-1)     echo "Asia Pacific (Mumbai)" ;;
        ap-south-2)     echo "Asia Pacific (Hyderabad)" ;;
        ap-southeast-1) echo "Asia Pacific (Singapore)" ;;
        ap-southeast-2) echo "Asia Pacific (Sydney)" ;;
        ap-southeast-3) echo "Asia Pacific (Jakarta)" ;;
        ap-southeast-4) echo "Asia Pacific (Melbourne)" ;;
        ap-northeast-1) echo "Asia Pacific (Tokyo)" ;;
        ap-northeast-2) echo "Asia Pacific (Seoul)" ;;
        ap-northeast-3) echo "Asia Pacific (Osaka)" ;;
        ca-central-1)   echo "Canada (Central)" ;;
        ca-west-1)      echo "Canada West (Calgary)" ;;
        eu-central-1)   echo "EU (Frankfurt)" ;;
        eu-central-2)   echo "EU (Zurich)" ;;
        eu-west-1)      echo "EU (Ireland)" ;;
        eu-west-2)      echo "EU (London)" ;;
        eu-west-3)      echo "EU (Paris)" ;;
        eu-south-1)     echo "EU (Milan)" ;;
        eu-south-2)     echo "EU (Spain)" ;;
        eu-north-1)     echo "EU (Stockholm)" ;;
        il-central-1)   echo "Israel (Tel Aviv)" ;;
        me-south-1)     echo "Middle East (Bahrain)" ;;
        me-central-1)   echo "Middle East (UAE)" ;;
        sa-east-1)      echo "South America (Sao Paulo)" ;;
        *)
            warn "Unknown region '$1' — pricing lookup may fail."
            echo "$1"
            ;;
    esac
}

# ============================================================================
# Pricing helpers
# ============================================================================

# Multiply two decimal numbers (works without bc by using awk)
calc() {
    awk "BEGIN {printf \"%.2f\", $1}"
}

# Query EC2 on-demand hourly price for an instance type + region
get_ec2_price() {
    local instance_type="$1"
    local region_name="$2"

    if [ "$USE_LIVE_PRICING" != "true" ]; then
        return 1
    fi

    local price
    price=$(aws pricing get-products \
        --service-code AmazonEC2 \
        --region us-east-1 \
        --filters \
            "Type=TERM_MATCH,Field=instanceType,Value=$instance_type" \
            "Type=TERM_MATCH,Field=location,Value=$region_name" \
            "Type=TERM_MATCH,Field=operatingSystem,Value=Linux" \
            "Type=TERM_MATCH,Field=tenancy,Value=Shared" \
            "Type=TERM_MATCH,Field=preInstalledSw,Value=NA" \
            "Type=TERM_MATCH,Field=capacitystatus,Value=Used" \
        --output json 2>/dev/null \
        | jq -r '.PriceList[0] | fromjson | .terms.OnDemand | to_entries[0].value.priceDimensions | to_entries[0].value.pricePerUnit.USD' 2>/dev/null) || return 1

    if [ -z "$price" ] || [ "$price" = "null" ]; then
        return 1
    fi
    echo "$price"
}

# Query EBS gp3 price per GB-month for a region
get_ebs_gp3_price() {
    local region_name="$1"

    if [ "$USE_LIVE_PRICING" != "true" ]; then
        return 1
    fi

    local price
    price=$(aws pricing get-products \
        --service-code AmazonEC2 \
        --region us-east-1 \
        --filters \
            "Type=TERM_MATCH,Field=volumeApiName,Value=gp3" \
            "Type=TERM_MATCH,Field=location,Value=$region_name" \
            "Type=TERM_MATCH,Field=productFamily,Value=Storage" \
        --output json 2>/dev/null \
        | jq -r '.PriceList[0] | fromjson | .terms.OnDemand | to_entries[0].value.priceDimensions | to_entries[0].value.pricePerUnit.USD' 2>/dev/null) || return 1

    if [ -z "$price" ] || [ "$price" = "null" ]; then
        return 1
    fi
    echo "$price"
}

# Hardcoded fallback prices (us-east-1 on-demand, Feb 2025)
fallback_ec2_price() {
    case "$1" in
        t3.large)       echo "0.0832" ;;
        t3.xlarge)      echo "0.1664" ;;
        t3.2xlarge)     echo "0.3328" ;;
        g4dn.xlarge)    echo "0.526"  ;;
        g4dn.2xlarge)   echo "0.752"  ;;
        g4dn.4xlarge)   echo "1.204"  ;;
        g4dn.8xlarge)   echo "2.176"  ;;
        g4dn.12xlarge)  echo "3.912"  ;;
        g5.xlarge)      echo "1.006"  ;;
        g5.2xlarge)     echo "1.212"  ;;
        g5.4xlarge)     echo "1.624"  ;;
        g5.8xlarge)     echo "2.448"  ;;
        g5.12xlarge)    echo "5.672"  ;;
        p3.2xlarge)     echo "3.06"   ;;
        p3.8xlarge)     echo "12.24"  ;;
        p3.16xlarge)    echo "24.48"  ;;
        *)              return 1      ;;
    esac
}

# ============================================================================
# Read configuration
# ============================================================================
REGION=$(cfg_get app.region "us-east-1")
REGION_NAME=$(region_to_name "$REGION")
CLIENT_TYPE=$(cfg_get machine.machine_type "g4dn.xlarge")
SSL_PROVIDER=$(cfg_get ssl.provider "none")
DNS_ENABLED=$(cfg_get dns.enabled "false")
MONITORING_ENABLED=$(cfg_get monitoring.enabled "false")
EIP_STRATEGY=$(cfg_get eip.strategy "dynamic")

ALLOCATOR_TYPE="t3.large"  # Hardcoded in Terraform
EBS_SIZE_GB=20              # Default Ubuntu AMI root volume

# ============================================================================
# Fetch prices
# ============================================================================
PRICING_SOURCE="AWS Pricing API"

# Allocator EC2
ALLOCATOR_HOURLY=$(get_ec2_price "$ALLOCATOR_TYPE" "$REGION_NAME" 2>/dev/null) || {
    ALLOCATOR_HOURLY=$(fallback_ec2_price "$ALLOCATOR_TYPE") || ALLOCATOR_HOURLY="0.0832"
    PRICING_SOURCE="hardcoded estimates"
}

# Client VM EC2
CLIENT_HOURLY=$(get_ec2_price "$CLIENT_TYPE" "$REGION_NAME" 2>/dev/null) || {
    CLIENT_HOURLY=$(fallback_ec2_price "$CLIENT_TYPE" 2>/dev/null) || {
        CLIENT_HOURLY=""
        warn "Could not determine price for instance type '$CLIENT_TYPE'."
    }
}

# EBS gp3
EBS_PER_GB=$(get_ebs_gp3_price "$REGION_NAME" 2>/dev/null) || {
    EBS_PER_GB="0.08"  # Typical gp3 price
    if [ "$PRICING_SOURCE" != "hardcoded estimates" ]; then
        PRICING_SOURCE="mixed (API + fallback)"
    fi
}

# ============================================================================
# Calculate monthly costs (730 hours/month)
# ============================================================================
HOURS_PER_MONTH=730

ALLOCATOR_MONTHLY=$(calc "$ALLOCATOR_HOURLY * $HOURS_PER_MONTH")
if [ -n "$CLIENT_HOURLY" ]; then
    CLIENT_MONTHLY=$(calc "$CLIENT_HOURLY * $HOURS_PER_MONTH")
else
    CLIENT_MONTHLY="?"
fi
EBS_MONTHLY=$(calc "$EBS_PER_GB * $EBS_SIZE_GB")

# Elastic IP: $0.005/hr for all public IPv4 addresses (since Feb 2024)
EIP_HOURLY="0.005"
EIP_MONTHLY=$(calc "$EIP_HOURLY * $HOURS_PER_MONTH")

# Fixed-cost line items
ROUTE53_MONTHLY="0.50"
CLOUDWATCH_MONTHLY="2.00"
CLOUDTRAIL_MONTHLY="3.00"
SNS_MONTHLY="1.00"
ALB_MONTHLY="20.00"

# ============================================================================
# Compute base infrastructure total
# ============================================================================
BASE_TOTAL="$ALLOCATOR_MONTHLY + $EBS_MONTHLY + $EIP_MONTHLY + $CLOUDWATCH_MONTHLY"

if [ "$DNS_ENABLED" = "true" ]; then
    BASE_TOTAL="$BASE_TOTAL + $ROUTE53_MONTHLY"
fi
if [ "$MONITORING_ENABLED" = "true" ]; then
    BASE_TOTAL="$BASE_TOTAL + $CLOUDTRAIL_MONTHLY + $SNS_MONTHLY"
fi
if [ "$SSL_PROVIDER" = "acm" ]; then
    BASE_TOTAL="$BASE_TOTAL + $ALB_MONTHLY"
fi

BASE_TOTAL=$(calc "$BASE_TOTAL")

# ============================================================================
# Print summary
# ============================================================================
echo ""
echo -e "${BOLD}${CYAN}LabLink Infrastructure Cost Estimate${NC}"
echo -e "${CYAN}=====================================${NC}"
echo -e "Region: ${BOLD}$REGION${NC} ($REGION_NAME)"
echo -e "Config: $CONFIG_FILE"
echo -e "Prices: $PRICING_SOURCE"
echo ""

# Table header
printf "  ${BOLD}%-37s %12s${NC}\n" "Resource" "Monthly Cost"
printf "  %-37s %12s\n" "-------------------------------------" "------------"

# Allocator EC2
printf "  %-37s ${GREEN}%11s${NC}\n" "Allocator EC2 ($ALLOCATOR_TYPE)" "\$${ALLOCATOR_MONTHLY}"

# Client VM EC2
if [ -n "$CLIENT_HOURLY" ]; then
    printf "  %-37s ${GREEN}%11s${NC}  *\n" "Client VM EC2 ($CLIENT_TYPE)" "\$${CLIENT_MONTHLY}"
else
    printf "  %-37s ${YELLOW}%11s${NC}  *\n" "Client VM EC2 ($CLIENT_TYPE)" "unknown"
fi

# EBS
printf "  %-37s ${GREEN}%11s${NC}\n" "EBS root volume (gp3, ${EBS_SIZE_GB} GB)" "\$${EBS_MONTHLY}"

# Elastic IP
printf "  %-37s ${GREEN}%11s${NC}\n" "Elastic IP" "\$${EIP_MONTHLY}"

# Route53
if [ "$DNS_ENABLED" = "true" ]; then
    printf "  %-37s ${GREEN}%11s${NC}\n" "Route53 hosted zone" "\$${ROUTE53_MONTHLY}"
fi

# CloudWatch
printf "  %-37s ${GREEN}%11s${NC}\n" "CloudWatch Logs" "\$${CLOUDWATCH_MONTHLY}"

# CloudTrail + SNS (if monitoring enabled)
if [ "$MONITORING_ENABLED" = "true" ]; then
    printf "  %-37s ${GREEN}%11s${NC}\n" "CloudTrail + S3" "\$${CLOUDTRAIL_MONTHLY}"
    printf "  %-37s ${GREEN}%11s${NC}\n" "SNS alerts" "\$${SNS_MONTHLY}"
fi

# ALB (if ACM SSL)
if [ "$SSL_PROVIDER" = "acm" ]; then
    printf "  %-37s ${GREEN}%11s${NC}\n" "ALB (ACM SSL)" "\$${ALB_MONTHLY}"
fi

# Totals
printf "  %-37s %12s\n" "-------------------------------------" "------------"
printf "  ${BOLD}%-37s ${GREEN}%11s${NC}/month\n" "Base infrastructure total" "\$${BASE_TOTAL}"
if [ -n "$CLIENT_HOURLY" ]; then
    printf "  ${BOLD}%-37s ${GREEN}%11s${NC}/month *\n" "Per client VM (when running)" "\$${CLIENT_MONTHLY}"
fi

# Usage example
echo ""
echo -e "${DIM}  * Client VM costs scale with usage. VMs are billed only while running.${NC}"
if [ -n "$CLIENT_HOURLY" ]; then
    EXAMPLE_COST=$(calc "$CLIENT_HOURLY * 8 * 22 * 10")
    echo -e "${DIM}    Example: 10 VMs x 8hr/day x 22 days/month = \$${EXAMPLE_COST}/month${NC}"
fi
echo -e "${DIM}  * Prices are on-demand estimates from ${PRICING_SOURCE}. Actual costs may vary.${NC}"
echo ""
