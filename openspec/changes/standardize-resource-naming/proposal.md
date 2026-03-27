## Why

This is a template repository intended to be forked and deployed by multiple teams. Currently, resources use a hardcoded `lablink-` prefix and only a single `resource_suffix` variable for environment differentiation. This prevents multiple deployments from coexisting in the same AWS account and makes cost allocation and resource management difficult.

Additionally, naming conventions are inconsistent (kebab-case vs underscores) and tags are minimal, making resource querying unreliable.

**Related Issue:** [#28 - Standardize Terraform resource naming for multi-deployment support](https://github.com/talmolab/lablink-template/issues/28)

## What Changes

- **BREAKING**: Add required `deployment_name` variable (no default)
- Rename `resource_suffix` to `environment` for clarity
- Standardize all resource names to format: `{deployment}-{resource-type}-{environment}`
- Standardize on kebab-case for all resources (currently IAM resources use underscores)
- Add consistent tags across all resources: `Project`, `ManagedBy`, `Repository`
- Update all backend configuration files
- Update example configuration files

## Impact

- **Affected specs:** infrastructure
- **Affected code:**
  - `lablink-infrastructure/main.tf` - Core resource definitions
  - `lablink-infrastructure/alb.tf` - ALB and security group resources
  - `lablink-infrastructure/cloudtrail.tf` - CloudTrail and S3 resources
  - `lablink-infrastructure/cloudwatch_alarms.tf` - Monitoring resources
  - `lablink-infrastructure/budget.tf` - Budget resources
  - `lablink-infrastructure/backend-*.hcl` - Backend configuration files
  - `lablink-infrastructure/config/*.yaml` - Example configuration files
  - `.github/workflows/*.yml` - CI/CD workflows
- **Migration:** Existing deployments must be destroyed and recreated with new naming (resources cannot be renamed in-place in AWS)