# Manual Cleanup Guide

## Overview

This guide provides step-by-step procedures for manually cleaning up AWS resources when the automated destroy workflow fails or leaves orphaned resources.

### When to Use This Guide

- Destroy workflow fails with errors
- Terraform state becomes corrupted or out of sync
- Resources remain after running destroy
- Need to clean up a test environment manually
- Troubleshooting partial deployment failures

### Prerequisites

- AWS CLI installed and configured
- Credentials with sufficient permissions (PowerUser or Administrator)
- Know your environment name (`test`, `prod`, `ci-test`, etc.)
- Know your S3 bucket name (from config.yaml: `bucket_name`)

### Safety Warnings

⚠️ **IMPORTANT**: Manual cleanup bypasses Terraform state tracking. Only use these procedures when automated destroy fails.

⚠️ **DATA LOSS**: These procedures permanently delete resources and data. Verify you're targeting the correct environment.

⚠️ **VERIFY FIRST**: Always list resources before deleting them to ensure you're removing the right ones.

---

## Quick Resource Verification

Before starting cleanup, verify what resources exist for your environment:

```bash
# Set your environment name
ENV="ci-test"  # or "test" or "prod"

# Check EC2 instances
aws ec2 describe-instances --region us-west-2 \
  --filters "Name=tag:Name,Values=*${ENV}*" \
  --query 'Reservations[*].Instances[*].[InstanceId,State.Name,Tags[?Key==`Name`].Value|[0]]' \
  --output table

# Check IAM roles
aws iam list-roles --query "Roles[?contains(RoleName, '${ENV}')].RoleName" --output table

# Check security groups
aws ec2 describe-security-groups --region us-west-2 \
  --filters "Name=group-name,Values=*${ENV}*" \
  --query 'SecurityGroups[*].[GroupId,GroupName]' \
  --output table

# Check key pairs
aws ec2 describe-key-pairs --region us-west-2 \
  --filters "Name=key-name,Values=*${ENV}*" \
  --query 'KeyPairs[*].KeyName' \
  --output table

# Check S3 state files
BUCKET="your-bucket-name"  # Replace with your bucket from config.yaml
aws s3 ls s3://${BUCKET}/${ENV}/ --recursive
```

---

## Manual Cleanup Procedures by Resource Type

### 1. IAM Resources

IAM resources must be cleaned in this order: detach policies → delete instance profiles → delete roles → delete custom policies.

#### A. List All IAM Resources for Environment

```bash
ENV="ci-test"

# List roles
echo "=== IAM Roles ==="
aws iam list-roles --query "Roles[?contains(RoleName, '${ENV}')].RoleName" --output table

# List policies
echo "=== IAM Policies ==="
aws iam list-policies --scope Local --query "Policies[?contains(PolicyName, '${ENV}')].PolicyName" --output table

# List instance profiles
echo "=== Instance Profiles ==="
aws iam list-instance-profiles --query "InstanceProfiles[?contains(InstanceProfileName, '${ENV}')].[InstanceProfileName,Roles[0].RoleName]" --output table
```

#### B. Delete CloudWatch Agent Role (Client VMs)

```bash
ENV="ci-test"
ROLE_NAME="lablink_cloud_watch_agent_role_${ENV}"
PROFILE_NAME="lablink_client_instance_profile_${ENV}"

# Detach managed policy
aws iam detach-role-policy \
  --role-name "${ROLE_NAME}" \
  --policy-arn "arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy"

# Remove role from instance profile
aws iam remove-role-from-instance-profile \
  --instance-profile-name "${PROFILE_NAME}" \
  --role-name "${ROLE_NAME}"

# Delete instance profile
aws iam delete-instance-profile --instance-profile-name "${PROFILE_NAME}"

# Delete role
aws iam delete-role --role-name "${ROLE_NAME}"

echo "✓ Deleted CloudWatch agent role"
```

#### C. Delete Allocator Instance Role

```bash
ENV="ci-test"
ROLE_NAME="lablink_instance_role_${ENV}"
PROFILE_NAME="lablink_instance_profile_${ENV}"

# Get custom policy ARN
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
POLICY_ARN="arn:aws:iam::${ACCOUNT_ID}:policy/lablink_s3_backend_${ENV}"

# Detach custom policy
aws iam detach-role-policy \
  --role-name "${ROLE_NAME}" \
  --policy-arn "${POLICY_ARN}"

# Remove role from instance profile
aws iam remove-role-from-instance-profile \
  --instance-profile-name "${PROFILE_NAME}" \
  --role-name "${ROLE_NAME}"

# Delete instance profile
aws iam delete-instance-profile --instance-profile-name "${PROFILE_NAME}"

# Delete role
aws iam delete-role --role-name "${ROLE_NAME}"

# Delete custom policy
aws iam delete-policy --policy-arn "${POLICY_ARN}"

echo "✓ Deleted allocator instance role and policy"
```

#### D. Delete Lambda Execution Role

```bash
ENV="ci-test"
ROLE_NAME="lablink_lambda_exec_${ENV}"

# Detach AWS managed policy
aws iam detach-role-policy \
  --role-name "${ROLE_NAME}" \
  --policy-arn "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"

# Delete role
aws iam delete-role --role-name "${ROLE_NAME}"

echo "✓ Deleted Lambda execution role"
```

---

### 2. Client VM Resources

Client VMs are created by the allocator and may be orphaned if the allocator is destroyed first.

#### A. Find and Terminate Client VMs

```bash
ENV="ci-test"

# List client VMs
echo "=== Client VMs ==="
aws ec2 describe-instances --region us-west-2 \
  --filters "Name=tag:Name,Values=lablink-vm-${ENV}-*" "Name=instance-state-name,Values=running,stopped" \
  --query 'Reservations[*].Instances[*].[InstanceId,State.Name,Tags[?Key==`Name`].Value|[0],LaunchTime]' \
  --output table

# Get instance IDs
INSTANCE_IDS=$(aws ec2 describe-instances --region us-west-2 \
  --filters "Name=tag:Name,Values=lablink-vm-${ENV}-*" "Name=instance-state-name,Values=running,stopped" \
  --query 'Reservations[*].Instances[*].InstanceId' \
  --output text)

# Terminate instances
if [ ! -z "$INSTANCE_IDS" ]; then
  echo "Terminating instances: $INSTANCE_IDS"
  aws ec2 terminate-instances --region us-west-2 --instance-ids $INSTANCE_IDS
  echo "✓ Client VMs terminating"
else
  echo "✓ No client VMs found"
fi
```

#### B. Delete Client VM Security Group

```bash
ENV="ci-test"
SG_NAME="lablink_client_${ENV}_sg"

# Find security group ID
SG_ID=$(aws ec2 describe-security-groups --region us-west-2 \
  --filters "Name=group-name,Values=${SG_NAME}" \
  --query 'SecurityGroups[0].GroupId' \
  --output text)

if [ "$SG_ID" != "None" ] && [ ! -z "$SG_ID" ]; then
  # Wait for instances to fully terminate
  echo "Waiting for instances to detach from security group..."
  sleep 30

  # Delete security group
  aws ec2 delete-security-group --region us-west-2 --group-id "${SG_ID}"
  echo "✓ Deleted client VM security group"
else
  echo "✓ No client VM security group found"
fi
```

#### C. Delete Client VM Key Pair

```bash
ENV="ci-test"
KEY_NAME="lablink_key_pair_client_${ENV}"

# Check if key exists
if aws ec2 describe-key-pairs --region us-west-2 --key-names "${KEY_NAME}" 2>/dev/null; then
  aws ec2 delete-key-pair --region us-west-2 --key-name "${KEY_NAME}"
  echo "✓ Deleted client VM key pair"
else
  echo "✓ No client VM key pair found"
fi
```

---

### 3. Allocator Infrastructure Resources

#### A. Terminate Allocator Instance

```bash
ENV="ci-test"

# Find allocator instance
INSTANCE_ID=$(aws ec2 describe-instances --region us-west-2 \
  --filters "Name=tag:Name,Values=lablink_allocator_server_${ENV}" "Name=instance-state-name,Values=running,stopped" \
  --query 'Reservations[0].Instances[0].InstanceId' \
  --output text)

if [ "$INSTANCE_ID" != "None" ] && [ ! -z "$INSTANCE_ID" ]; then
  aws ec2 terminate-instances --region us-west-2 --instance-ids "${INSTANCE_ID}"
  echo "✓ Allocator instance terminating: ${INSTANCE_ID}"
else
  echo "✓ No allocator instance found"
fi
```

#### B. Release Elastic IP (if using dynamic strategy)

```bash
ENV="ci-test"

# Find EIP allocation ID
ALLOCATION_ID=$(aws ec2 describe-addresses --region us-west-2 \
  --filters "Name=tag:Name,Values=lablink-eip-${ENV}" \
  --query 'Addresses[0].AllocationId' \
  --output text)

if [ "$ALLOCATION_ID" != "None" ] && [ ! -z "$ALLOCATION_ID" ]; then
  aws ec2 release-address --region us-west-2 --allocation-id "${ALLOCATION_ID}"
  echo "✓ Released Elastic IP"
else
  echo "✓ No Elastic IP found"
fi
```

#### C. Delete Allocator Security Group

```bash
ENV="ci-test"
SG_NAME="allow_http_https_${ENV}"

# Find security group ID
SG_ID=$(aws ec2 describe-security-groups --region us-west-2 \
  --filters "Name=group-name,Values=${SG_NAME}" \
  --query 'SecurityGroups[0].GroupId' \
  --output text)

if [ "$SG_ID" != "None" ] && [ ! -z "$SG_ID" ]; then
  aws ec2 delete-security-group --region us-west-2 --group-id "${SG_ID}"
  echo "✓ Deleted allocator security group"
else
  echo "✓ No allocator security group found"
fi
```

#### D. Delete Allocator Key Pair

```bash
ENV="ci-test"
KEY_NAME="lablink-key-${ENV}"

if aws ec2 describe-key-pairs --region us-west-2 --key-names "${KEY_NAME}" 2>/dev/null; then
  aws ec2 delete-key-pair --region us-west-2 --key-name "${KEY_NAME}"
  echo "✓ Deleted allocator key pair"
else
  echo "✓ No allocator key pair found"
fi
```

---

### 4. DNS Resources

If using Terraform-managed DNS (`dns.terraform_managed: true`), you may need to manually remove DNS records.

```bash
ENV="ci-test"
ZONE_ID="Z1038183268T83E91AYJF"  # Replace with your zone ID
RECORD_NAME="ci-test.lablink-template-testing.com"  # Replace with your record

# List A records
aws route53 list-resource-record-sets \
  --hosted-zone-id "${ZONE_ID}" \
  --query "ResourceRecordSets[?Name=='${RECORD_NAME}.']"

# If record exists, create a change batch file
cat > /tmp/delete-record.json <<EOF
{
  "Changes": [
    {
      "Action": "DELETE",
      "ResourceRecordSet": {
        "Name": "${RECORD_NAME}",
        "Type": "A",
        "TTL": 300,
        "ResourceRecords": [
          {
            "Value": "1.2.3.4"
          }
        ]
      }
    }
  ]
}
EOF

# Note: Replace "Value" with actual IP from list command above
# Then run:
# aws route53 change-resource-record-sets --hosted-zone-id "${ZONE_ID}" --change-batch file:///tmp/delete-record.json
```

---

### 5. CloudWatch Resources

CloudWatch log groups may contain valuable historical logs. Consider archiving before deletion.

```bash
ENV="ci-test"

# List log groups
echo "=== CloudWatch Log Groups ==="
aws logs describe-log-groups --region us-west-2 \
  --log-group-name-prefix lablink \
  --query "logGroups[?contains(logGroupName, '${ENV}')].logGroupName" \
  --output table

# Delete client VM log group
LOG_GROUP="lablink-cloud-init-${ENV}"
if aws logs describe-log-groups --region us-west-2 --log-group-name-prefix "${LOG_GROUP}" --query "logGroups[0]" 2>/dev/null; then
  aws logs delete-log-group --region us-west-2 --log-group-name "${LOG_GROUP}"
  echo "✓ Deleted ${LOG_GROUP}"
fi

# Delete Lambda log group
LOG_GROUP="/aws/lambda/lablink_log_processor_${ENV}"
if aws logs describe-log-groups --region us-west-2 --log-group-name-prefix "${LOG_GROUP}" --query "logGroups[0]" 2>/dev/null; then
  aws logs delete-log-group --region us-west-2 --log-group-name "${LOG_GROUP}"
  echo "✓ Deleted ${LOG_GROUP}"
fi
```

---

### 6. Lambda Functions

```bash
ENV="ci-test"
FUNCTION_NAME="lablink_log_processor_${ENV}"

# Check if function exists
if aws lambda get-function --function-name "${FUNCTION_NAME}" --region us-west-2 2>/dev/null; then
  aws lambda delete-function --function-name "${FUNCTION_NAME}" --region us-west-2
  echo "✓ Deleted Lambda function"
else
  echo "✓ No Lambda function found"
fi
```

---

### 7. S3 and DynamoDB State Management

#### A. List State Files

```bash
ENV="ci-test"
BUCKET="your-bucket-name"  # Replace with your bucket

# List all state files for environment
aws s3 ls s3://${BUCKET}/${ENV}/ --recursive
```

#### B. Backup State Files (Recommended)

```bash
ENV="ci-test"
BUCKET="your-bucket-name"
BACKUP_DIR="./terraform-state-backup-$(date +%Y%m%d-%H%M%S)"

# Create backup directory
mkdir -p "${BACKUP_DIR}"

# Download state files
aws s3 cp s3://${BUCKET}/${ENV}/ "${BACKUP_DIR}/" --recursive

echo "✓ State files backed up to ${BACKUP_DIR}"
```

#### C. Delete State Files

```bash
ENV="ci-test"
BUCKET="your-bucket-name"

# Delete infrastructure state
aws s3 rm s3://${BUCKET}/${ENV}/terraform.tfstate

# Delete client VM state
aws s3 rm s3://${BUCKET}/${ENV}/client/terraform.tfstate
aws s3 rm s3://${BUCKET}/${ENV}/client/terraform.runtime.tfvars

echo "✓ State files deleted"
```

#### D. Clean DynamoDB Lock Entries

**⚠️ CRITICAL**: Only delete lock entries if you're certain no Terraform operations are running.

```bash
ENV="ci-test"
BUCKET="your-bucket-name"

# List lock entries for environment
aws dynamodb scan --table-name lock-table --region us-west-2 \
  --filter-expression "contains(LockID, :prefix)" \
  --expression-attribute-values "{\":prefix\": {\"S\": \"${BUCKET}/${ENV}\"}}" \
  --query 'Items[*].LockID.S' \
  --output table

# Delete infrastructure state lock
aws dynamodb delete-item --table-name lock-table --region us-west-2 \
  --key "{\"LockID\": {\"S\": \"${BUCKET}/${ENV}/terraform.tfstate-md5\"}}"

# Delete client VM state lock
aws dynamodb delete-item --table-name lock-table --region us-west-2 \
  --key "{\"LockID\": {\"S\": \"${BUCKET}/${ENV}/client/terraform.tfstate-md5\"}}"

echo "✓ DynamoDB lock entries deleted"
```

---

## Common Failure Scenarios

### Scenario 1: "State Data in S3 Does Not Have Expected Content"

**Error:**
```
Error refreshing state: state data in S3 does not have the expected content.
The checksum calculated for the state stored in S3 does not match the checksum stored in DynamoDB.
```

**Cause:** DynamoDB has a digest entry for a state file that doesn't exist, is empty, or was modified outside of Terraform.

**Fix:**

```bash
ENV="ci-test"
BUCKET="your-bucket-name"

# Delete the corrupted DynamoDB digest entry
aws dynamodb delete-item --table-name lock-table --region us-west-2 \
  --key "{\"LockID\": {\"S\": \"${BUCKET}/${ENV}/client/terraform.tfstate-md5\"}}"

# If state file is corrupted, delete it
aws s3 rm s3://${BUCKET}/${ENV}/client/terraform.tfstate

echo "✓ Fixed checksum mismatch"
```

---

### Scenario 2: "Cannot Delete Entity, Must Detach All Policies First"

**Error:**
```
An error occurred (DeleteConflict) when calling the DeleteRole operation:
Cannot delete entity, must detach all policies first.
```

**Cause:** Trying to delete an IAM role that still has policies attached.

**Fix:**

```bash
ROLE_NAME="lablink_instance_role_ci-test"

# List attached policies
echo "Attached policies:"
aws iam list-attached-role-policies --role-name "${ROLE_NAME}"

# Detach each policy (get ARN from list above)
aws iam detach-role-policy --role-name "${ROLE_NAME}" --policy-arn "arn:aws:iam::ACCOUNT:policy/POLICY_NAME"

# Now delete role
aws iam delete-role --role-name "${ROLE_NAME}"
```

---

### Scenario 3: "Cannot Delete Entity, Must Remove Roles from Instance Profile First"

**Error:**
```
An error occurred (DeleteConflict) when calling the DeleteRole operation:
Cannot delete entity, must remove roles from instance profile first.
```

**Cause:** Role is still attached to an instance profile.

**Fix:**

```bash
ROLE_NAME="lablink_cloud_watch_agent_role_ci-test"

# Find instance profile
PROFILE_NAME=$(aws iam list-instance-profiles-for-role --role-name "${ROLE_NAME}" \
  --query 'InstanceProfiles[0].InstanceProfileName' --output text)

# Remove role from instance profile
aws iam remove-role-from-instance-profile \
  --instance-profile-name "${PROFILE_NAME}" \
  --role-name "${ROLE_NAME}"

# Delete instance profile
aws iam delete-instance-profile --instance-profile-name "${PROFILE_NAME}"

# Now delete role
aws iam delete-role --role-name "${ROLE_NAME}"
```

---

### Scenario 4: "Security Group Cannot Be Deleted (Resource in Use)"

**Error:**
```
An error occurred (DependencyViolation) when calling the DeleteSecurityGroup operation:
resource sg-xxx has a dependent object
```

**Cause:** Security group is still attached to running or recently terminated instances.

**Fix:**

```bash
SG_ID="sg-xxx"

# Check what's using it
aws ec2 describe-network-interfaces --region us-west-2 \
  --filters "Name=group-id,Values=${SG_ID}"

# Wait for instances to fully terminate (can take 1-2 minutes)
echo "Waiting 60 seconds for instances to detach..."
sleep 60

# Retry deletion
aws ec2 delete-security-group --region us-west-2 --group-id "${SG_ID}"
```

---

### Scenario 5: Orphaned Client VMs After Allocator Destroyed

**Situation:** Allocator was destroyed but client VMs are still running.

**Fix:** Follow [Section 2: Client VM Resources](#2-client-vm-resources) to:
1. Terminate client VMs
2. Delete client security group
3. Delete client key pair
4. Clean up client VM state files

---

## Complete Cleanup Script

For convenience, here's a complete script that cleans up all resources for an environment:

```bash
#!/bin/bash
set -e

# Configuration
ENV="ci-test"  # CHANGE THIS
BUCKET="your-bucket-name"  # CHANGE THIS
REGION="us-west-2"

echo "=== Cleaning up environment: ${ENV} ==="
echo "WARNING: This will delete all resources for ${ENV}"
read -p "Continue? (type 'yes' to confirm): " CONFIRM

if [ "$CONFIRM" != "yes" ]; then
  echo "Aborted"
  exit 1
fi

ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)

echo ""
echo "1. Terminating EC2 instances..."
# Client VMs
INSTANCE_IDS=$(aws ec2 describe-instances --region ${REGION} \
  --filters "Name=tag:Name,Values=lablink-vm-${ENV}-*" "Name=instance-state-name,Values=running,stopped" \
  --query 'Reservations[*].Instances[*].InstanceId' --output text)
if [ ! -z "$INSTANCE_IDS" ]; then
  aws ec2 terminate-instances --region ${REGION} --instance-ids $INSTANCE_IDS
  echo "  ✓ Terminated client VMs"
fi

# Allocator
INSTANCE_ID=$(aws ec2 describe-instances --region ${REGION} \
  --filters "Name=tag:Name,Values=lablink_allocator_server_${ENV}" "Name=instance-state-name,Values=running,stopped" \
  --query 'Reservations[0].Instances[0].InstanceId' --output text)
if [ "$INSTANCE_ID" != "None" ] && [ ! -z "$INSTANCE_ID" ]; then
  aws ec2 terminate-instances --region ${REGION} --instance-ids ${INSTANCE_ID}
  echo "  ✓ Terminated allocator"
fi

echo ""
echo "2. Waiting for instances to terminate..."
sleep 30

echo ""
echo "3. Deleting security groups..."
# Client SG
SG_ID=$(aws ec2 describe-security-groups --region ${REGION} \
  --filters "Name=group-name,Values=lablink_client_${ENV}_sg" \
  --query 'SecurityGroups[0].GroupId' --output text 2>/dev/null || echo "")
if [ ! -z "$SG_ID" ] && [ "$SG_ID" != "None" ]; then
  aws ec2 delete-security-group --region ${REGION} --group-id ${SG_ID} 2>/dev/null && echo "  ✓ Deleted client SG" || echo "  ⚠ Client SG deletion failed (may need retry)"
fi

# Allocator SG
SG_ID=$(aws ec2 describe-security-groups --region ${REGION} \
  --filters "Name=group-name,Values=allow_http_https_${ENV}" \
  --query 'SecurityGroups[0].GroupId' --output text 2>/dev/null || echo "")
if [ ! -z "$SG_ID" ] && [ "$SG_ID" != "None" ]; then
  aws ec2 delete-security-group --region ${REGION} --group-id ${SG_ID} 2>/dev/null && echo "  ✓ Deleted allocator SG" || echo "  ⚠ Allocator SG deletion failed (may need retry)"
fi

echo ""
echo "4. Deleting key pairs..."
aws ec2 delete-key-pair --region ${REGION} --key-name "lablink_key_pair_client_${ENV}" 2>/dev/null && echo "  ✓ Deleted client key" || true
aws ec2 delete-key-pair --region ${REGION} --key-name "lablink-key-${ENV}" 2>/dev/null && echo "  ✓ Deleted allocator key" || true

echo ""
echo "5. Releasing Elastic IP..."
ALLOCATION_ID=$(aws ec2 describe-addresses --region ${REGION} \
  --filters "Name=tag:Name,Values=lablink-eip-${ENV}" \
  --query 'Addresses[0].AllocationId' --output text 2>/dev/null || echo "")
if [ ! -z "$ALLOCATION_ID" ] && [ "$ALLOCATION_ID" != "None" ]; then
  aws ec2 release-address --region ${REGION} --allocation-id ${ALLOCATION_ID}
  echo "  ✓ Released EIP"
fi

echo ""
echo "6. Deleting Lambda function..."
aws lambda delete-function --function-name "lablink_log_processor_${ENV}" --region ${REGION} 2>/dev/null && echo "  ✓ Deleted Lambda" || true

echo ""
echo "7. Deleting IAM resources..."
# Lambda role
aws iam detach-role-policy --role-name "lablink_lambda_exec_${ENV}" \
  --policy-arn "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole" 2>/dev/null || true
aws iam delete-role --role-name "lablink_lambda_exec_${ENV}" 2>/dev/null && echo "  ✓ Deleted Lambda role" || true

# CloudWatch agent role
aws iam detach-role-policy --role-name "lablink_cloud_watch_agent_role_${ENV}" \
  --policy-arn "arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy" 2>/dev/null || true
aws iam remove-role-from-instance-profile \
  --instance-profile-name "lablink_client_instance_profile_${ENV}" \
  --role-name "lablink_cloud_watch_agent_role_${ENV}" 2>/dev/null || true
aws iam delete-instance-profile --instance-profile-name "lablink_client_instance_profile_${ENV}" 2>/dev/null || true
aws iam delete-role --role-name "lablink_cloud_watch_agent_role_${ENV}" 2>/dev/null && echo "  ✓ Deleted CloudWatch agent role" || true

# Instance role
aws iam detach-role-policy --role-name "lablink_instance_role_${ENV}" \
  --policy-arn "arn:aws:iam::${ACCOUNT_ID}:policy/lablink_s3_backend_${ENV}" 2>/dev/null || true
aws iam remove-role-from-instance-profile \
  --instance-profile-name "lablink_instance_profile_${ENV}" \
  --role-name "lablink_instance_role_${ENV}" 2>/dev/null || true
aws iam delete-instance-profile --instance-profile-name "lablink_instance_profile_${ENV}" 2>/dev/null || true
aws iam delete-role --role-name "lablink_instance_role_${ENV}" 2>/dev/null && echo "  ✓ Deleted instance role" || true
aws iam delete-policy --policy-arn "arn:aws:iam::${ACCOUNT_ID}:policy/lablink_s3_backend_${ENV}" 2>/dev/null && echo "  ✓ Deleted S3 backend policy" || true

echo ""
echo "8. Deleting CloudWatch log groups..."
aws logs delete-log-group --region ${REGION} --log-group-name "lablink-cloud-init-${ENV}" 2>/dev/null && echo "  ✓ Deleted client log group" || true
aws logs delete-log-group --region ${REGION} --log-group-name "/aws/lambda/lablink_log_processor_${ENV}" 2>/dev/null && echo "  ✓ Deleted Lambda log group" || true

echo ""
echo "9. Cleaning S3 state files..."
aws s3 rm s3://${BUCKET}/${ENV}/terraform.tfstate 2>/dev/null && echo "  ✓ Deleted infrastructure state" || true
aws s3 rm s3://${BUCKET}/${ENV}/client/ --recursive 2>/dev/null && echo "  ✓ Deleted client state" || true

echo ""
echo "10. Cleaning DynamoDB lock entries..."
aws dynamodb delete-item --table-name lock-table --region ${REGION} \
  --key "{\"LockID\": {\"S\": \"${BUCKET}/${ENV}/terraform.tfstate-md5\"}}" 2>/dev/null && echo "  ✓ Deleted infrastructure lock" || true
aws dynamodb delete-item --table-name lock-table --region ${REGION} \
  --key "{\"LockID\": {\"S\": \"${BUCKET}/${ENV}/client/terraform.tfstate-md5\"}}" 2>/dev/null && echo "  ✓ Deleted client lock" || true

echo ""
echo "=== Cleanup complete for ${ENV} ==="
echo ""
echo "Run verification commands to ensure everything is cleaned up."
```

Save this as `scripts/cleanup-environment.sh`, make it executable with `chmod +x scripts/cleanup-environment.sh`, and run it with your environment name and bucket configured at the top.

---

## Verification Checklist

After manual cleanup, verify all resources are removed:

```bash
ENV="ci-test"
BUCKET="your-bucket-name"

echo "=== Verification for ${ENV} ==="

echo "EC2 Instances:"
aws ec2 describe-instances --region us-west-2 \
  --filters "Name=tag:Name,Values=*${ENV}*" "Name=instance-state-name,Values=running,stopped" \
  --query 'Reservations[*].Instances[*].[InstanceId,State.Name]' --output table

echo "IAM Roles:"
aws iam list-roles --query "Roles[?contains(RoleName, '${ENV}')].RoleName" --output table

echo "Security Groups:"
aws ec2 describe-security-groups --region us-west-2 \
  --filters "Name=group-name,Values=*${ENV}*" \
  --query 'SecurityGroups[*].[GroupId,GroupName]' --output table

echo "Key Pairs:"
aws ec2 describe-key-pairs --region us-west-2 \
  --filters "Name=key-name,Values=*${ENV}*" --query 'KeyPairs[*].KeyName' --output table

echo "Elastic IPs:"
aws ec2 describe-addresses --region us-west-2 \
  --filters "Name=tag:Name,Values=*${ENV}*" --query 'Addresses[*].[AllocationId,PublicIp]' --output table

echo "CloudWatch Log Groups:"
aws logs describe-log-groups --region us-west-2 --log-group-name-prefix lablink \
  --query "logGroups[?contains(logGroupName, '${ENV}')].logGroupName" --output table

echo "S3 State Files:"
aws s3 ls s3://${BUCKET}/${ENV}/ --recursive

echo "DynamoDB Locks:"
aws dynamodb scan --table-name lock-table --region us-west-2 \
  --filter-expression "contains(LockID, :env)" \
  --expression-attribute-values "{\":env\": {\"S\": \"${ENV}\"}}" \
  --query 'Items[*].LockID.S' --output table

echo ""
echo "If all outputs are empty, cleanup is complete!"
```

---

## Getting Help

If you encounter issues not covered in this guide:

1. Check the [README.md](README.md) for general troubleshooting
2. Review the [DEPLOYMENT_CHECKLIST.md](DEPLOYMENT_CHECKLIST.md) for deployment verification steps
3. Check AWS CloudWatch logs for error messages
4. Open an issue in the GitHub repository with:
   - The error message
   - What resources remain (from verification commands)
   - Your environment name and configuration

---

## Best Practices

1. **Always backup state files** before deleting them
2. **Verify before deleting** - use list commands first
3. **Delete in order** - follow the dependency chain (policies → profiles → roles)
4. **Use scripts** for repeatable cleanup
5. **Document deviations** - if you modify procedures, update this guide
6. **Test in ci-test first** - verify cleanup procedures work before using in prod
