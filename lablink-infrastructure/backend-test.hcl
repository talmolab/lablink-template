# Backend configuration for TEST environment
# Uses S3 backend for shared state management
# State stored in: s3://<bucket_name>/test/terraform.tfstate
#
# Usage (Local):
#   ../scripts/init-terraform.sh test  # Reads bucket from config/config.yaml
#   tofu plan -var="deployment_name=YOUR-DEPLOYMENT" -var="environment=test"
#   tofu apply -var="deployment_name=YOUR-DEPLOYMENT" -var="environment=test"
#
# Usage (Manual):
#   tofu init -backend-config=backend-test.hcl -backend-config="bucket=YOUR-BUCKET"
#   tofu plan -var="deployment_name=YOUR-DEPLOYMENT" -var="environment=test"
#   tofu apply -var="deployment_name=YOUR-DEPLOYMENT" -var="environment=test"
#
# Usage (GitHub Actions):
#   Workflow: Deploy LabLink Infrastructure
#   Choose environment: test
#
# Resource naming: {deployment_name}-{resource-type}-test (e.g., sleap-lablink-eip-test)
key            = "test/terraform.tfstate"
dynamodb_table = "lock-table"
encrypt        = true
