# Migration Guide: Standardized Resource Naming

## Breaking Change

All Terraform resources now use the naming pattern `{deployment_name}-{resource-type}-{environment}` instead of the previous `lablink-{resource}-{suffix}` pattern. This requires a full infrastructure recreation.

## New Required Variable

A new `deployment_name` variable is required (no default). This is a unique kebab-case identifier for your deployment (e.g., `sleap-lablink`, `deeplabcut-lablink`).

The old `resource_suffix` variable has been renamed to `environment`.

## Migration Steps

### 1. Destroy existing infrastructure

Using the **old** code (before pulling this change):

```bash
cd lablink-infrastructure
terraform destroy -var="resource_suffix=<your-env>"
```

Or use the GitHub Actions "Destroy LabLink Infrastructure" workflow.

### 2. Pull the new code

```bash
git pull origin main
```

### 3. Update your config.yaml

- Remove the `eip.tag_name` field (EIP name is now derived from `deployment_name`)
- No other config changes required

### 4. Pre-tag your persistent EIP (if using persistent strategy)

If you use `eip.strategy: "persistent"`, tag your existing EIP with the new naming:

```bash
aws ec2 create-tags \
  --resources <your-eip-allocation-id> \
  --tags Key=Name,Value=<deployment_name>-eip-<environment> Key=Environment,Value=<environment>
```

### 5. Deploy with new variables

```bash
cd lablink-infrastructure
../scripts/init-terraform.sh <environment>
terraform plan \
  -var="deployment_name=<your-deployment-name>" \
  -var="environment=<your-env>"
terraform apply \
  -var="deployment_name=<your-deployment-name>" \
  -var="environment=<your-env>"
```

Or use the GitHub Actions "Deploy LabLink Infrastructure" workflow with the new `deployment_name` input.

### 6. Verify resources

```bash
aws resourcegroupstaggingapi get-resources \
  --tag-filters Key=Project,Values=<your-deployment-name>
```

## Variable Mapping

| Old | New |
|-----|-----|
| `resource_suffix` | `environment` |
| _(none)_ | `deployment_name` (required) |
| _(none)_ | `repository` (optional) |

## Rollback

This change cannot be rolled back without destroying and recreating infrastructure. If you need to revert, destroy the new-named resources and redeploy using a commit before this change.
