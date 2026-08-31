#!/bin/bash
# cleanup-orphaned-resources.sh
# Manually clean up orphaned AWS resources for a LabLink deployment.
#
# Usage: ./scripts/cleanup-orphaned-resources.sh <environment> [--deployment-name NAME] [--dry-run] [--yes]
# Example: ./scripts/cleanup-orphaned-resources.sh test --dry-run
# Example: ./scripts/cleanup-orphaned-resources.sh test --deployment-name sleap-lablink --yes
#
# Runs from any directory: it resolves the repository from its own path. This differs
# from setup.sh, configure.sh and estimate-costs.sh, which must be run from the
# repository root.
#
# Flags:
#   --deployment-name NAME  Override the deployment_name read from config.yaml.
#                           Needed when recovering a CI deploy, because the deploy
#                           workflow pins deployment_name from its own input rather
#                           than from the committed config.
#   --dry-run               Show what would be deleted without making changes
#   --yes                   Skip confirmation prompt and proceed automatically
#
# Environment variables:
#   NO_COLOR   Set to any value to disable colored output

set -e

# Colors for output (respects NO_COLOR environment variable)
if [ -z "${NO_COLOR:-}" ] && [ -t 1 ]; then
  RED='\033[0;31m'
  GREEN='\033[0;32m'
  YELLOW='\033[1;33m'
  BLUE='\033[0;34m'
  DIM='\033[2m'
  NC='\033[0m' # No Color
else
  RED=''
  GREEN=''
  YELLOW=''
  BLUE=''
  DIM=''
  NC=''
fi

# Script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(dirname "$SCRIPT_DIR")"
CONFIG_FILE="$REPO_ROOT/lablink-infrastructure/config/config.yaml"

# Parse arguments
ENV=""
DEPLOYMENT=""
DRY_RUN=false
AUTO_CONFIRM=false

while [ $# -gt 0 ]; do
  case "$1" in
    --dry-run)
      DRY_RUN=true
      ;;
    --yes)
      AUTO_CONFIRM=true
      ;;
    --deployment-name)
      DEPLOYMENT="${2:-}"
      if [ -z "$DEPLOYMENT" ]; then
        echo -e "${RED}Error: --deployment-name requires a value${NC}"
        exit 1
      fi
      shift
      ;;
    -*)
      echo -e "${RED}Error: unknown flag '$1'${NC}"
      exit 1
      ;;
    *)
      if [ -z "$ENV" ]; then
        ENV="$1"
      fi
      ;;
  esac
  shift
done

if [ -z "$ENV" ]; then
  echo -e "${RED}Error: Environment name required${NC}"
  echo "Usage: $0 <environment> [--deployment-name NAME] [--dry-run] [--yes]"
  echo "Example: $0 test --dry-run"
  exit 1
fi

if [ "$DRY_RUN" = true ]; then
  echo -e "${YELLOW}DRY RUN MODE - No resources will be deleted${NC}"
  echo ""
fi

# Extract configuration from config.yaml
echo -e "${BLUE}Reading configuration...${NC}"

if [ ! -f "$CONFIG_FILE" ]; then
  echo -e "${RED}Error: Config file not found: $CONFIG_FILE${NC}"
  exit 1
fi

# Extract bucket name
BUCKET=$(grep "^bucket_name:" "$CONFIG_FILE" | awk '{print $2}' | tr -d '"')
if [ -z "$BUCKET" ]; then
  echo -e "${RED}Error: bucket_name not found in $CONFIG_FILE${NC}"
  exit 1
fi

# Every allocator-side resource name is prefixed with deployment_name, so without it
# there is nothing to look up. Refuse rather than fall back to a bare-environment
# wildcard: in an account holding more than one deployment that would match — and
# delete — another deployment's resources.
if [ -z "$DEPLOYMENT" ]; then
  DEPLOYMENT=$(grep "^deployment_name:" "$CONFIG_FILE" | awk '{print $2}' | tr -d '"')
fi
if [ -z "$DEPLOYMENT" ]; then
  echo -e "${RED}Error: deployment_name not found in $CONFIG_FILE${NC}"
  echo "  Pass it explicitly: $0 $ENV --deployment-name YOUR-DEPLOYMENT"
  exit 1
fi

# Extract region from config.yaml, fall back to AWS CLI config
REGION=$(grep -A 5 "^app:" "$CONFIG_FILE" | grep "^  region:" | awk '{print $2}' | tr -d '"')
if [ -z "$REGION" ]; then
  echo -e "${YELLOW}Region not found in config.yaml, checking AWS CLI configuration...${NC}"
  REGION=$(aws configure get region 2>/dev/null || echo "")
fi

if [ -z "$REGION" ]; then
  echo -e "${YELLOW}Region not configured, defaulting to us-west-2${NC}"
  REGION="us-west-2"
fi

# A persistent EIP is pre-allocated by the operator and reused across deployments —
# and it carries the same Name tag as a dynamic one (main.tf:290-306), so the tag
# alone cannot tell them apart. Releasing it would throw away the stable address the
# strategy exists to keep, so the strategy decides whether step 6 runs at all.
EIP_STRATEGY=$(awk '/^eip:/{f=1} f && /strategy:/{print $2; exit}' "$CONFIG_FILE" 2>/dev/null | tr -d '"' | sed 's/ *#.*//' | xargs 2>/dev/null || true)
EIP_STRATEGY="${EIP_STRATEGY:-dynamic}"

echo -e "${GREEN}Configuration:${NC}"
echo "  Deployment:  $DEPLOYMENT"
echo "  Environment: $ENV"
echo "  S3 Bucket:   $BUCKET"
echo "  AWS Region:  $REGION"
echo "  EIP strategy: $EIP_STRATEGY"
echo ""

# Get AWS account ID
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text 2>/dev/null || echo "")
if [ -z "$ACCOUNT_ID" ]; then
  echo -e "${RED}Error: Unable to get AWS account ID. Are AWS credentials configured?${NC}"
  exit 1
fi
echo "  Account ID:  $ACCOUNT_ID"
echo ""

# ============================================================================
# Resource names
#
# These mirror lablink-infrastructure/main.tf and alb.tf exactly. Keep them in
# step: a rename there turns every lookup below into a silent no-op, which is how
# this script came to target resources that had not existed for some time.
#
# Allocator-side names are "{deployment_name}-{resource}-{environment}".
# ============================================================================
ALLOC_INSTANCE_TAG="${DEPLOYMENT}-allocator-${ENV}"          # main.tf:285
ALLOC_SG="${DEPLOYMENT}-allocator-sg-${ENV}"                 # main.tf:218
ALLOC_KEYPAIR="${DEPLOYMENT}-keypair-${ENV}"                 # main.tf:209
ALLOC_EIP_TAG="${DEPLOYMENT}-eip-${ENV}"                     # main.tf:305
ALLOC_ROLE="${DEPLOYMENT}-allocator-role-${ENV}"             # main.tf:410
ALLOC_PROFILE="${DEPLOYMENT}-allocator-profile-${ENV}"       # main.tf:437
ALB_NAME="${DEPLOYMENT}-alb-${ENV}"                          # alb.tf:70
ALB_TG="${DEPLOYMENT}-alb-tg-${ENV}"                         # alb.tf:89
ALB_SG="${DEPLOYMENT}-alb-sg-${ENV}"                         # alb.tf:14

# Client resources are created by the *allocator's* own OpenTofu, whose
# resource_prefix is "{software}-lablink-client-{environment}" (see
# routes/provisioning.py in talmolab/lablink). That prefix carries no
# deployment_name, so these are matched by wildcard on the environment. Two
# deployments sharing both software and environment collide upstream; nothing this
# script can do disambiguates them.
CLIENT_VM_TAG="*-lablink-client-${ENV}-vm-*"
CLIENT_SG="*-lablink-client-${ENV}-sg"
CLIENT_KEYPAIR="*-lablink-client-${ENV}-keypair"
CLIENT_ROLE_SUFFIX="-lablink-client-${ENV}-vm-role"
CLIENT_PROFILE_SUFFIX="-lablink-client-${ENV}-instance-profile"

# State keys. The allocator writes client state under
# "{deployment_name}/{environment}/client/terraform.tfstate" (main.py in
# talmolab/lablink), while this repo's own state is "{environment}/terraform.tfstate"
# (backend-{env}.hcl). They are NOT the same prefix.
ALLOC_STATE_KEY="${ENV}/terraform.tfstate"
CLIENT_STATE_PREFIX="${DEPLOYMENT}/${ENV}/client"

# ============================================================================
# Result tracking
#
# A miss is reported as "[--] not found", never as a green [OK]. The old script
# printed success for both, so a run that matched nothing at all looked identical
# to a clean teardown.
# ============================================================================
DELETED=0
ABSENT=0
FAILED=0

ok()     { echo -e "  ${GREEN}[OK]${NC} $*"; DELETED=$((DELETED + 1)); }
absent() { echo -e "  ${DIM}[--] $*${NC}"; ABSENT=$((ABSENT + 1)); }
would()  { echo -e "  ${YELLOW}[DRY RUN]${NC} $*"; }
oops()   { echo -e "  ${RED}[FAIL]${NC} $*"; FAILED=$((FAILED + 1)); }

# aws ... --output text prints a literal "None" for an empty scalar query result and
# an empty string for an empty list. Treat both as "nothing found".
empty() { [ -z "$1" ] || [ "$1" = "None" ]; }

# ============================================================================
# Helpers, one per resource class
# ============================================================================

terminate_instances() { # <tag-name-pattern> <label>
  local pattern="$1" label="$2" ids
  ids=$(aws ec2 describe-instances --region "$REGION" \
    --filters "Name=tag:Name,Values=${pattern}" \
              "Name=instance-state-name,Values=running,stopped,pending" \
    --query 'Reservations[*].Instances[*].InstanceId' \
    --output text 2>/dev/null || echo "")

  if empty "$ids"; then
    absent "no ${label} (${pattern})"
    return
  fi

  TERMINATED_ANY=true
  if [ "$DRY_RUN" = true ]; then
    would "terminate ${label}: ${ids}"
    return
  fi

  local id_arr
  read -r -a id_arr <<< "$ids"
  aws ec2 terminate-instances --region "$REGION" --instance-ids "${id_arr[@]}" >/dev/null
  ok "terminated ${label}: ${ids}"
}

delete_alb() { # <alb-name>
  local name="$1" arn
  arn=$(aws elbv2 describe-load-balancers --region "$REGION" --names "$name" \
    --query 'LoadBalancers[0].LoadBalancerArn' --output text 2>/dev/null || echo "")

  if empty "$arn"; then
    absent "no load balancer ${name}"
    return
  fi

  TERMINATED_ANY=true
  if [ "$DRY_RUN" = true ]; then
    would "delete load balancer ${name}"
    return
  fi

  # Deleting the ALB removes its listeners with it; the target group outlives it.
  if aws elbv2 delete-load-balancer --region "$REGION" --load-balancer-arn "$arn" 2>/dev/null; then
    ok "deleted load balancer ${name}"
  else
    oops "could not delete load balancer ${name}"
  fi
}

delete_target_group() { # <target-group-name>
  local name="$1" arn
  arn=$(aws elbv2 describe-target-groups --region "$REGION" --names "$name" \
    --query 'TargetGroups[0].TargetGroupArn' --output text 2>/dev/null || echo "")

  if empty "$arn"; then
    absent "no target group ${name}"
    return
  fi

  if [ "$DRY_RUN" = true ]; then
    would "delete target group ${name}"
    return
  fi

  if aws elbv2 delete-target-group --region "$REGION" --target-group-arn "$arn" 2>/dev/null; then
    ok "deleted target group ${name}"
  else
    oops "could not delete target group ${name} (still referenced by a listener?)"
  fi
}

delete_security_groups() { # <group-name-pattern> <label>
  local pattern="$1" label="$2" ids sg_arr sg
  ids=$(aws ec2 describe-security-groups --region "$REGION" \
    --filters "Name=group-name,Values=${pattern}" \
    --query 'SecurityGroups[*].GroupId' --output text 2>/dev/null || echo "")

  if empty "$ids"; then
    absent "no ${label} security group (${pattern})"
    return
  fi

  if [ "$DRY_RUN" = true ]; then
    would "delete ${label} security group(s): ${ids}"
    return
  fi

  read -r -a sg_arr <<< "$ids"
  for sg in "${sg_arr[@]}"; do
    if aws ec2 delete-security-group --region "$REGION" --group-id "$sg" 2>/dev/null; then
      ok "deleted ${label} security group: ${sg}"
    else
      # Almost always a lingering ENI from an instance or ALB that has not finished
      # detaching. Re-running the script after a minute usually clears it.
      oops "${label} security group still in use, retry shortly: ${sg}"
    fi
  done
}

delete_key_pairs() { # <key-name-pattern> <label>
  local pattern="$1" label="$2" names name_arr name
  names=$(aws ec2 describe-key-pairs --region "$REGION" \
    --filters "Name=key-name,Values=${pattern}" \
    --query 'KeyPairs[*].KeyName' --output text 2>/dev/null || echo "")

  if empty "$names"; then
    absent "no ${label} key pair (${pattern})"
    return
  fi

  if [ "$DRY_RUN" = true ]; then
    would "delete ${label} key pair(s): ${names}"
    return
  fi

  read -r -a name_arr <<< "$names"
  for name in "${name_arr[@]}"; do
    if aws ec2 delete-key-pair --region "$REGION" --key-name "$name" 2>/dev/null; then
      ok "deleted ${label} key pair: ${name}"
    else
      oops "could not delete ${label} key pair: ${name}"
    fi
  done
}

# Delete an IAM role and the instance profile fronting it. Detaches *every* attached
# managed policy rather than a hardcoded one: main.tf attaches two policies
# (s3-backend and ec2-mgmt), and delete-role fails while any remains attached.
delete_role_and_profile() { # <role-name> <profile-name> <label>
  local role="$1" profile="$2" label="$3" policies pol_arr pol

  if ! aws iam get-role --role-name "$role" >/dev/null 2>&1; then
    absent "no ${label} role ${role}"
  elif [ "$DRY_RUN" = true ]; then
    would "delete ${label} role ${role} (detaching its policies first)"
  else
    policies=$(aws iam list-attached-role-policies --role-name "$role" \
      --query 'AttachedPolicies[*].PolicyArn' --output text 2>/dev/null || echo "")
    if ! empty "$policies"; then
      read -r -a pol_arr <<< "$policies"
      for pol in "${pol_arr[@]}"; do
        aws iam detach-role-policy --role-name "$role" --policy-arn "$pol" 2>/dev/null || true
      done
    fi
    aws iam remove-role-from-instance-profile \
      --instance-profile-name "$profile" --role-name "$role" 2>/dev/null || true
    if aws iam delete-role --role-name "$role" 2>/dev/null; then
      ok "deleted ${label} role: ${role}"
    else
      oops "could not delete ${label} role: ${role}"
    fi
  fi

  if ! aws iam get-instance-profile --instance-profile-name "$profile" >/dev/null 2>&1; then
    absent "no ${label} instance profile ${profile}"
  elif [ "$DRY_RUN" = true ]; then
    would "delete ${label} instance profile ${profile}"
  elif aws iam delete-instance-profile --instance-profile-name "$profile" 2>/dev/null; then
    ok "deleted ${label} instance profile: ${profile}"
  else
    oops "could not delete ${label} instance profile: ${profile}"
  fi
}

delete_policy() { # <policy-name>
  local name="$1" arn="arn:aws:iam::${ACCOUNT_ID}:policy/$1"

  if ! aws iam get-policy --policy-arn "$arn" >/dev/null 2>&1; then
    absent "no policy ${name}"
    return
  fi

  if [ "$DRY_RUN" = true ]; then
    would "delete policy ${name}"
    return
  fi

  if aws iam delete-policy --policy-arn "$arn" 2>/dev/null; then
    ok "deleted policy: ${name}"
  else
    oops "could not delete policy ${name} (still attached somewhere?)"
  fi
}

# The client role and profile are named from the allocator's resource_prefix, which
# has no deployment_name, so they can only be found by suffix rather than looked up
# by an exact name.
find_by_suffix() { # <list-command> <jmespath-collection> <field> <suffix>
  aws iam "$1" --query "$2[?ends_with($3, \`$4\`)].$3" --output text 2>/dev/null || echo ""
}

# ============================================================================
# Verification: what actually exists, scoped to this deployment
# ============================================================================
echo -e "${YELLOW}=== Verification: Checking what exists ===${NC}"
echo ""

echo "EC2 instances:"
aws ec2 describe-instances --region "$REGION" \
  --filters "Name=tag:Name,Values=${ALLOC_INSTANCE_TAG},${CLIENT_VM_TAG}" \
            "Name=instance-state-name,Values=running,stopped,pending" \
  --query 'Reservations[*].Instances[*].[InstanceId,State.Name,Tags[?Key==`Name`].Value|[0]]' \
  --output table 2>/dev/null || echo "  none found"

echo "Security groups:"
aws ec2 describe-security-groups --region "$REGION" \
  --filters "Name=group-name,Values=${ALLOC_SG},${ALB_SG},${CLIENT_SG}" \
  --query 'SecurityGroups[*].[GroupId,GroupName]' \
  --output table 2>/dev/null || echo "  none found"

echo "Key pairs:"
aws ec2 describe-key-pairs --region "$REGION" \
  --filters "Name=key-name,Values=${ALLOC_KEYPAIR},${CLIENT_KEYPAIR}" \
  --query 'KeyPairs[*].KeyName' --output table 2>/dev/null || echo "  none found"

echo "IAM roles:"
aws iam list-roles \
  --query "Roles[?RoleName=='${ALLOC_ROLE}' || ends_with(RoleName, \`${CLIENT_ROLE_SUFFIX}\`)].RoleName" \
  --output table 2>/dev/null || echo "  none found"

echo ""

# Confirmation prompt
if [ "$DRY_RUN" = false ] && [ "$AUTO_CONFIRM" = false ]; then
  echo -e "${RED}WARNING: This will permanently delete resources for deployment '${DEPLOYMENT}' in environment '${ENV}'${NC}"
  echo -e "${RED}This action cannot be undone!${NC}"
  echo ""
  read -r -p "Type 'yes' to confirm deletion: " CONFIRM

  if [ "$CONFIRM" != "yes" ]; then
    echo "Aborted"
    exit 1
  fi
  echo ""
fi

echo -e "${BLUE}=== Starting cleanup: ${DEPLOYMENT} / ${ENV} ===${NC}"
echo ""

TERMINATED_ANY=false

# Step 1: Terminate EC2 Instances
echo -e "${BLUE}1. Terminating EC2 instances...${NC}"
terminate_instances "$CLIENT_VM_TAG" "client VMs"
terminate_instances "$ALLOC_INSTANCE_TAG" "allocator"

# Step 2: Delete the ALB and its target group
#
# Before the security groups, not after: the ALB holds ENIs in its own security
# group, and delete-security-group fails while they exist.
echo ""
echo -e "${BLUE}2. Deleting load balancer...${NC}"
delete_alb "$ALB_NAME"

# Step 3: Wait for instances and the ALB to release their ENIs
echo ""
echo -e "${BLUE}3. Waiting for resources to detach...${NC}"
if [ "$DRY_RUN" = false ] && [ "$TERMINATED_ANY" = true ]; then
  echo "  Waiting 30 seconds..."
  sleep 30
elif [ "$DRY_RUN" = true ]; then
  echo -e "  ${YELLOW}[DRY RUN]${NC} Would wait 30 seconds"
else
  echo -e "  ${DIM}[--] nothing was terminated, no wait needed${NC}"
fi

delete_target_group "$ALB_TG"

# Step 4: Delete Security Groups
echo ""
echo -e "${BLUE}4. Deleting security groups...${NC}"
delete_security_groups "$CLIENT_SG" "client"
delete_security_groups "$ALLOC_SG" "allocator"
delete_security_groups "$ALB_SG" "ALB"

# Step 5: Delete Key Pairs
echo ""
echo -e "${BLUE}5. Deleting key pairs...${NC}"
delete_key_pairs "$CLIENT_KEYPAIR" "client"
delete_key_pairs "$ALLOC_KEYPAIR" "allocator"

# Step 6: Release Elastic IP (dynamic strategy only)
echo ""
echo -e "${BLUE}6. Releasing Elastic IP...${NC}"
if [ "$EIP_STRATEGY" != "dynamic" ]; then
  echo -e "  ${DIM}[--] eip.strategy is '${EIP_STRATEGY}', keeping the EIP${NC}"
  echo -e "  ${DIM}     A persistent EIP is meant to outlive the deployment. Release it by"
  echo -e "       hand if you really want the address back.${NC}"
else
  ALLOCATION_IDS=$(aws ec2 describe-addresses --region "$REGION" \
    --filters "Name=tag:Name,Values=${ALLOC_EIP_TAG}" \
    --query 'Addresses[*].AllocationId' --output text 2>/dev/null || echo "")

  if empty "$ALLOCATION_IDS"; then
    absent "no Elastic IP tagged ${ALLOC_EIP_TAG}"
  elif [ "$DRY_RUN" = true ]; then
    would "release Elastic IP(s): ${ALLOCATION_IDS}"
  else
    read -r -a EIP_ARR <<< "$ALLOCATION_IDS"
    for alloc in "${EIP_ARR[@]}"; do
      if aws ec2 release-address --region "$REGION" --allocation-id "$alloc" 2>/dev/null; then
        ok "released Elastic IP: ${alloc}"
      else
        oops "could not release Elastic IP: ${alloc}"
      fi
    done
  fi
fi

# Step 7: Delete IAM Resources
echo ""
echo -e "${BLUE}7. Deleting IAM resources...${NC}"
delete_role_and_profile "$ALLOC_ROLE" "$ALLOC_PROFILE" "allocator"
delete_policy "${DEPLOYMENT}-s3-backend-policy-${ENV}"
delete_policy "${DEPLOYMENT}-ec2-mgmt-policy-${ENV}"

CLIENT_ROLES=$(find_by_suffix list-roles Roles RoleName "$CLIENT_ROLE_SUFFIX")
if empty "$CLIENT_ROLES"; then
  absent "no client role (*${CLIENT_ROLE_SUFFIX})"
else
  read -r -a CLIENT_ROLE_ARR <<< "$CLIENT_ROLES"
  for client_role in "${CLIENT_ROLE_ARR[@]}"; do
    # The profile shares the role's resource_prefix, so it is derivable from the name.
    delete_role_and_profile \
      "$client_role" \
      "${client_role%"$CLIENT_ROLE_SUFFIX"}${CLIENT_PROFILE_SUFFIX}" \
      "client"
  done
fi

# Step 8: Clean S3 State Files
echo ""
echo -e "${BLUE}8. Cleaning S3 state files...${NC}"

if [ "$DRY_RUN" = false ]; then
  # Back up before deleting: a state file is the only record of what was created,
  # and this script runs precisely when that record is the last thing left.
  BACKUP_DIR="$REPO_ROOT/terraform-state-backup-$(date +%Y%m%d-%H%M%S)"
  mkdir -p "${BACKUP_DIR}"
  echo "  Backing up state to ${BACKUP_DIR}..."
  aws s3 cp "s3://${BUCKET}/${ENV}/" "${BACKUP_DIR}/allocator/" --recursive 2>/dev/null \
    && ok "backed up allocator state" || absent "no allocator state to back up"
  aws s3 cp "s3://${BUCKET}/${CLIENT_STATE_PREFIX}/" "${BACKUP_DIR}/client/" --recursive 2>/dev/null \
    && ok "backed up client state" || absent "no client state to back up"

  aws s3 rm "s3://${BUCKET}/${ALLOC_STATE_KEY}" 2>/dev/null \
    && ok "deleted allocator state (${ALLOC_STATE_KEY})" \
    || absent "no allocator state at ${ALLOC_STATE_KEY}"
  aws s3 rm "s3://${BUCKET}/${CLIENT_STATE_PREFIX}/" --recursive 2>/dev/null \
    && ok "deleted client state (${CLIENT_STATE_PREFIX}/)" \
    || absent "no client state at ${CLIENT_STATE_PREFIX}/"
else
  would "back up and delete s3://${BUCKET}/${ALLOC_STATE_KEY}"
  would "back up and delete s3://${BUCKET}/${CLIENT_STATE_PREFIX}/"
fi

# Step 9: Clean DynamoDB Lock Entries
echo ""
echo -e "${BLUE}9. Cleaning DynamoDB lock entries...${NC}"

# The LockID is the state object's path plus "-md5", so it follows the same two
# prefixes the state files do.
ALLOC_LOCK="${BUCKET}/${ALLOC_STATE_KEY}-md5"
CLIENT_LOCK="${BUCKET}/${CLIENT_STATE_PREFIX}/terraform.tfstate-md5"

if [ "$DRY_RUN" = false ]; then
  for lock in "$ALLOC_LOCK" "$CLIENT_LOCK"; do
    if aws dynamodb delete-item --table-name lock-table --region "$REGION" \
      --key "{\"LockID\": {\"S\": \"${lock}\"}}" 2>/dev/null; then
      ok "cleared lock: ${lock}"
    else
      absent "no lock: ${lock}"
    fi
  done
else
  would "delete DynamoDB lock ${ALLOC_LOCK}"
  would "delete DynamoDB lock ${CLIENT_LOCK}"
fi

# ============================================================================
# Summary
# ============================================================================
echo ""
if [ "$DRY_RUN" = true ]; then
  echo -e "${YELLOW}This was a dry run. No resources were deleted.${NC}"
  echo "To actually delete resources, run without --dry-run:"
  echo "  $0 $ENV --deployment-name $DEPLOYMENT"
  echo ""
  exit 0
fi

echo -e "${BLUE}=== Cleanup summary: ${DEPLOYMENT} / ${ENV} ===${NC}"
echo -e "  ${GREEN}${DELETED} deleted${NC}, ${DIM}${ABSENT} not found${NC}, ${RED}${FAILED} failed${NC}"
echo ""

if [ "$FAILED" -gt 0 ]; then
  echo -e "${YELLOW}Some deletions failed.${NC} Security groups usually just need a"
  echo "retry once their ENIs detach; anything else, see docs/MANUAL_CLEANUP_GUIDE.md."
  echo ""
  exit 1
fi

if [ "$DELETED" -eq 0 ]; then
  echo -e "${YELLOW}Nothing was deleted.${NC} Either this deployment is already clean, or"
  echo "the deployment name is wrong — check it against the resource names above:"
  echo "  aws ec2 describe-instances --region ${REGION} \\"
  echo "    --filters \"Name=tag:Name,Values=*-allocator-${ENV}\" \\"
  echo "    --query 'Reservations[*].Instances[*].Tags[?Key==\`Name\`].Value' --output text"
  echo ""
  exit 0
fi

echo "Verify with:"
echo "  aws ec2 describe-instances --region ${REGION} \\"
echo "    --filters \"Name=tag:Name,Values=${ALLOC_INSTANCE_TAG},${CLIENT_VM_TAG}\" \\"
echo "    --query 'Reservations[*].Instances[*].[InstanceId,State.Name]' --output table"
echo ""
