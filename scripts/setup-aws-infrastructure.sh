#!/bin/bash
# Setup AWS infrastructure for LabLink deployment
# Creates S3 bucket, DynamoDB table, and Route53 hosted zone

set -e

echo "LabLink AWS Infrastructure Setup"
echo "================================"
echo ""

# Check prerequisites
echo "Checking prerequisites..."
echo ""

# 1. Check if AWS CLI is installed
if ! command -v aws &> /dev/null; then
    echo "❌ Error: AWS CLI is not installed"
    echo ""
    echo "Please install AWS CLI v2: https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html"
    echo ""
    exit 1
fi

echo "✅ AWS CLI is installed ($(aws --version))"

# 2. Check if AWS credentials are configured
if ! aws sts get-caller-identity &> /dev/null; then
    echo "❌ Error: AWS credentials are not configured"
    echo ""
    echo "Please configure AWS credentials:"
    echo "  aws configure"
    echo ""
    echo "Documentation: https://docs.aws.amazon.com/cli/latest/userguide/cli-configure-quickstart.html"
    echo ""
    exit 1
fi

CALLER_IDENTITY=$(aws sts get-caller-identity --query 'Arn' --output text 2>/dev/null || echo "unknown")
echo "✅ AWS credentials are configured ($CALLER_IDENTITY)"
echo ""

echo "This script will create AWS resources needed for LabLink deployment:"
echo "  - S3 bucket for Terraform state"
echo "  - DynamoDB table for state locking"
echo "  - Route53 hosted zone (if DNS enabled in config)"
echo ""

# Check if config.yaml exists
CONFIG_FILE="lablink-infrastructure/config/config.yaml"

if [ ! -f "$CONFIG_FILE" ]; then
    echo "Error: Configuration file not found: $CONFIG_FILE"
    echo ""
    echo "Please create config.yaml first:"
    echo "  cp lablink-infrastructure/config/example.config.yaml lablink-infrastructure/config/config.yaml"
    echo "  # Edit config.yaml with your values"
    exit 1
fi

# Extract values from config.yaml
echo "Reading configuration from: $CONFIG_FILE"
BUCKET_NAME=$(grep "^bucket_name:" "$CONFIG_FILE" | awk '{print $2}' | tr -d '"')
REGION=$(grep -A 5 "^app:" "$CONFIG_FILE" | grep "^  region:" | awk '{print $2}' | tr -d '"')
DNS_ENABLED=$(grep -A 20 "^dns:" "$CONFIG_FILE" | grep "^  enabled:" | awk '{print $2}' | tr -d '"')
DOMAIN=$(grep -A 20 "^dns:" "$CONFIG_FILE" | grep "^  domain:" | head -1 | awk '{print $2}' | tr -d '"')

# Validate required values
if [ -z "$BUCKET_NAME" ] || [ -z "$REGION" ]; then
    echo "Error: Could not extract required values from config file"
    echo "  bucket_name: $BUCKET_NAME"
    echo "  region: $REGION"
    exit 1
fi

# Derive zone name from domain (extract root domain: example.com from test.example.com)
ZONE_NAME=""
if [ "$DNS_ENABLED" = "true" ] && [ -n "$DOMAIN" ]; then
    ZONE_NAME=$(echo "$DOMAIN" | awk -F. '{if (NF>=2) print $(NF-1)"."$NF}')
fi

echo ""
echo "Configuration:"
echo "  S3 Bucket: $BUCKET_NAME"
echo "  AWS Region: $REGION"
if [ -n "$ZONE_NAME" ]; then
    echo "  Route53 Zone: $ZONE_NAME"
    echo "  Full Domain: $DOMAIN"
else
    echo "  DNS: Disabled"
fi
echo ""
read -p "Proceed with setup? [y/N]: " CONFIRM

if [ "$CONFIRM" != "y" ] && [ "$CONFIRM" != "Y" ]; then
    echo "Aborted"
    exit 0
fi

# 1. Create S3 bucket
echo ""
echo "Creating S3 bucket for Terraform state..."
if aws s3 ls "s3://$BUCKET_NAME" 2>/dev/null; then
    echo "✅ Bucket already exists: $BUCKET_NAME"
else
    aws s3 mb "s3://$BUCKET_NAME" --region "$REGION"
    echo "✅ Created bucket: $BUCKET_NAME"

    # Enable versioning
    aws s3api put-bucket-versioning \
        --bucket "$BUCKET_NAME" \
        --versioning-configuration Status=Enabled \
        --region "$REGION"
    echo "✅ Enabled versioning on bucket"
fi

# 2. Create DynamoDB table for state locking
echo ""
echo "Creating DynamoDB table for state locking..."
if aws dynamodb describe-table --table-name lock-table --region "$REGION" 2>/dev/null; then
    echo "✅ DynamoDB table already exists: lock-table"
else
    aws dynamodb create-table \
        --table-name lock-table \
        --attribute-definitions AttributeName=LockID,AttributeType=S \
        --key-schema AttributeName=LockID,KeyType=HASH \
        --billing-mode PAY_PER_REQUEST \
        --region "$REGION"
    echo "✅ Created DynamoDB table: lock-table"
fi

# 3. Create Route53 hosted zone (if DNS enabled)
ZONE_ID=""
if [ -n "$ZONE_NAME" ]; then
    echo ""
    echo "Checking Route53 hosted zone setup..."

    # Check if zone(s) already exist
    EXISTING_ZONES=$(aws route53 list-hosted-zones-by-name \
        --dns-name "$ZONE_NAME" \
        --query "HostedZones[?Name=='${ZONE_NAME}.'].Id" \
        --output text 2>/dev/null || echo "")

    ZONE_COUNT=$(echo "$EXISTING_ZONES" | wc -w | tr -d ' ')

    if [ "$ZONE_COUNT" -eq 0 ]; then
        # No zone exists - create one
        echo "No hosted zone found for: $ZONE_NAME"
        echo "Creating Route53 hosted zone..."

        ZONE_OUTPUT=$(aws route53 create-hosted-zone \
            --name "$ZONE_NAME" \
            --caller-reference "$(date +%s)" \
            --query 'HostedZone.Id' \
            --output text)
        ZONE_ID=$(echo "$ZONE_OUTPUT" | sed 's|/hostedzone/||')
        echo "✅ Created hosted zone: $ZONE_NAME (ID: $ZONE_ID)"

        # Get nameservers
        NS_RECORDS=$(aws route53 get-hosted-zone --id "$ZONE_ID" \
            --query 'DelegationSet.NameServers' \
            --output text)

        echo ""
        echo "⚠️  IMPORTANT: Update your domain registrar with these nameservers:"
        echo "$NS_RECORDS" | tr '\t' '\n' | sed 's/^/  - /'

    elif [ "$ZONE_COUNT" -eq 1 ]; then
        # One zone exists - use it
        ZONE_ID=$(echo "$EXISTING_ZONES" | sed 's|/hostedzone/||')
        echo "✅ Found existing hosted zone: $ZONE_NAME (ID: $ZONE_ID)"

        # Check if this was created by Route53 registrar
        ZONE_COMMENT=$(aws route53 get-hosted-zone --id "$ZONE_ID" \
            --query 'HostedZone.Config.Comment' --output text 2>/dev/null || echo "")

        if echo "$ZONE_COMMENT" | grep -q "Route53 Registrar"; then
            echo "ℹ️  Zone was auto-created by Route53 domain registration"
        fi

    else
        # Multiple zones exist - error
        echo "❌ ERROR: Multiple hosted zones found for $ZONE_NAME"
        echo ""
        echo "Found $ZONE_COUNT zones:"
        aws route53 list-hosted-zones-by-name --dns-name "$ZONE_NAME" \
            --query "HostedZones[?Name=='${ZONE_NAME}.'].[Id,Config.Comment]" \
            --output table
        echo ""
        echo "Action required:"
        echo "1. Determine which zone your domain uses:"
        echo "   - Check domain nameservers: aws route53domains get-domain-detail --domain-name $ZONE_NAME --region us-east-1"
        echo "   - Or check with your external registrar"
        echo "2. Delete duplicate zones manually:"
        echo "   aws route53 delete-hosted-zone --id ZONE_ID_TO_DELETE"
        echo "3. Or manually set zone_id in $CONFIG_FILE to specify which zone to use"
        echo "4. Then re-run this script"
        exit 1
    fi

    # Update config file with zone_id
    echo ""
    echo "Updating config file with zone_id..."

    # Use proper sed syntax for macOS/Linux compatibility
    if [[ "$OSTYPE" == "darwin"* ]]; then
        # macOS
        sed -i '' "s|zone_id: \".*\"|zone_id: \"$ZONE_ID\"|" "$CONFIG_FILE"
    else
        # Linux
        sed -i "s|zone_id: \".*\"|zone_id: \"$ZONE_ID\"|" "$CONFIG_FILE"
    fi

    echo "✅ Updated $CONFIG_FILE with zone_id: $ZONE_ID"
fi

# Summary
echo ""
echo "================================"
echo "Setup Complete!"
echo "================================"
echo ""
echo "Created resources:"
echo "  ✅ S3 Bucket: $BUCKET_NAME"
echo "  ✅ DynamoDB Table: lock-table"
if [ -n "$ZONE_ID" ]; then
    echo "  ✅ Route53 Zone: $ZONE_NAME (ID: $ZONE_ID)"
fi
echo ""
echo "Next steps:"
echo "  1. Review updated config file: $CONFIG_FILE"
if [ -n "$ZONE_ID" ]; then
    echo "  2. Update domain registrar nameservers (if new zone)"
    echo "  3. Wait for DNS propagation (up to 48 hours, usually minutes)"
    echo "  4. Initialize Terraform: ./scripts/init-terraform.sh test"
    echo "  5. Deploy infrastructure: terraform apply -var=\"resource_suffix=test\""
else
    echo "  2. Initialize Terraform: ./scripts/init-terraform.sh test"
    echo "  3. Deploy infrastructure: terraform apply -var=\"resource_suffix=test\""
fi
echo ""
