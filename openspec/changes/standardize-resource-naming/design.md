## Context

LabLink Infrastructure Template is designed to be forked by multiple research labs. Each lab may deploy multiple environments (dev, test, prod) and some labs share AWS accounts. The current hardcoded `lablink-` prefix and inconsistent naming prevents:

1. Multiple deployments in the same AWS account
2. Easy cost allocation per project
3. Reliable resource querying via AWS Resource Groups Tagging API
4. Clear resource ownership and traceability

## Goals / Non-Goals

**Goals:**
- Enable multiple independent deployments in a single AWS account
- Provide consistent, predictable resource naming
- Support cost allocation and resource querying via tags
- Maintain backwards compatibility in configuration structure

**Non-Goals:**
- Zero-downtime migration (resources must be recreated)
- Supporting mixed naming conventions within a deployment
- Changing the Terraform state backend structure

## Decisions

### Decision 1: Two-Variable Naming Scheme

**What:** Introduce `deployment_name` (required) and rename `resource_suffix` to `environment`.

**Why:** Separating deployment identity from environment allows:
- Same deployment across environments: `sleap-lablink-alb-dev`, `sleap-lablink-alb-prod`
- Different deployments in same account: `sleap-lablink-alb-prod`, `deeplabcut-lablink-alb-prod`

**Alternatives considered:**
- Single combined variable: Rejected because it conflates identity with environment
- Three variables (org/project/env): Rejected as over-engineered for current needs

### Decision 2: Naming Format `{deployment}-{resource-type}-{environment}`

**What:** All resources follow the pattern `{deployment_name}-{resource_type}-{environment}`.

**Why:**
- Deployment first enables AWS console sorting by project
- Resource type in middle provides context
- Environment last enables easy filtering (e.g., `*-prod`)

**Examples:**
| Resource | Name |
|----------|------|
| ALB | `sleap-lablink-alb-prod` |
| Security Group (ALB) | `sleap-lablink-alb-sg-prod` |
| IAM Role (allocator) | `sleap-lablink-allocator-role-prod` |
| S3 Bucket | `sleap-lablink-cloudtrail-bucket-prod-{account_id}` |
| CloudWatch Alarm | `sleap-lablink-alarm-mass-launch-prod` |

### Decision 3: Standardize on Kebab-Case

**What:** Use kebab-case (`-`) for all resources, including IAM.

**Why:**
- Consistency across all AWS resource types
- More readable than underscores
- AWS allows kebab-case in IAM resource names

**Current inconsistencies to fix:**
- IAM roles: `lablink_instance_role_*` → `{deployment}-allocator-role-{env}`
- IAM policies: `lablink_s3_backend_*` → `{deployment}-s3-backend-policy-{env}`
- Lambda functions: `lablink_log_processor_*` → `{deployment}-log-processor-{env}`
- Security group: `allow_http_https_*` → `{deployment}-allocator-sg-{env}`

### Decision 4: Standard Tag Set

**What:** Apply five tags to all taggable resources.

| Tag | Source | Purpose |
|-----|--------|---------|
| `Name` | Computed | Resource identifier |
| `Environment` | `var.environment` | Deployment environment |
| `Project` | `var.deployment_name` | Cost allocation, resource grouping |
| `ManagedBy` | `"terraform"` (hardcoded) | Distinguish from manual resources |
| `Repository` | `var.repository` (optional) | Traceability to source code |

**Why:**
- `Project` enables AWS Cost Explorer grouping
- `ManagedBy` helps identify orphaned manual resources
- `Repository` provides audit trail for infrastructure changes

### Decision 5: Local Variables for Name Construction

**What:** Use Terraform locals to construct names consistently.

```hcl
locals {
  name_prefix = "${var.deployment_name}"
  name_suffix = "${var.environment}"

  # Standard tags applied to all resources
  common_tags = {
    Environment = var.environment
    Project     = var.deployment_name
    ManagedBy   = "terraform"
    Repository  = var.repository
  }
}

# Usage example
resource "aws_lb" "allocator_alb" {
  name = "${local.name_prefix}-alb-${local.name_suffix}"
  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-alb-${local.name_suffix}"
  })
}
```

**Why:**
- Single source of truth for naming logic
- Easy to update format in one place
- Reduces copy-paste errors

## Risks / Trade-offs

| Risk | Mitigation |
|------|------------|
| Breaking change requires infrastructure recreation | Document migration steps; provide destroy-then-apply workflow |
| Longer resource names may hit AWS limits | Test all resource types; S3 bucket names have 63-char limit |
| Existing deployments become orphaned | Clear migration documentation; announce in release notes |

## Migration Plan

1. **Announce breaking change** in release notes
2. **Users destroy existing infrastructure** using current naming
3. **Users update configuration** with new `deployment_name` variable
4. **Users deploy fresh** with new naming convention
5. **Verify resources** using AWS Resource Groups Tagging API query

**Rollback:** Not applicable (this is a naming change, not a feature that can be toggled).

## Open Questions

- Should `repository` tag be required or optional with sensible default?
- Should we add a `CostCenter` tag for organizations with billing codes?