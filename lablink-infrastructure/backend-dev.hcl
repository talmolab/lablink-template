# Backend configuration for DEV environment
# Uses S3 backend, same as every other environment.
# State stored in: s3://<bucket_name>/dev/terraform.tfstate
#
# Local state was advertised here but never worked: backend.tf hardcodes
# `backend "s3" {}`, so an empty -backend-config left `tofu init` prompting for
# a bucket (#60). It could not work anyway — the allocator scopes its *client*
# VM state to s3://{bucket_name}/{deployment_name}/{environment}/ and main.tf
# grants its IAM role exactly that prefix, so a real bucket is required in dev
# regardless of where the allocator's own state lives.
#
# Usage (Local):
#   ../scripts/init-terraform.sh dev  # Reads bucket from config/config.yaml
#   tofu plan -var="deployment_name=YOUR-DEPLOYMENT" -var="environment=dev"
#   tofu apply -var="deployment_name=YOUR-DEPLOYMENT" -var="environment=dev"
#
# Usage (Manual):
#   tofu init -backend-config=backend-dev.hcl -backend-config="bucket=YOUR-BUCKET"
#   tofu plan -var="deployment_name=YOUR-DEPLOYMENT" -var="environment=dev"
#   tofu apply -var="deployment_name=YOUR-DEPLOYMENT" -var="environment=dev"
#
# Usage (GitHub Actions):
#   NOT AVAILABLE - dev is for local iteration only, to keep a developer's
#   experiments off the shared test/prod environments.
#
# Resource naming: {deployment_name}-{resource-type}-dev (e.g., sleap-lablink-eip-dev)
key            = "dev/terraform.tfstate"
dynamodb_table = "lock-table"
encrypt        = true
