## ADDED Requirements

### Requirement: Deployment Name Variable
The infrastructure SHALL require a `deployment_name` variable to uniquely identify each deployment within an AWS account.

#### Scenario: Deployment name is required
- **WHEN** `deployment_name` is not provided
- **THEN** Terraform fails with a validation error

#### Scenario: Deployment name used in resource names
- **WHEN** `deployment_name="sleap-lablink"` AND `environment="prod"`
- **THEN** all resource names start with `sleap-lablink-`

#### Scenario: Deployment name validation
- **WHEN** `deployment_name` contains invalid characters (uppercase, underscores, spaces)
- **THEN** Terraform fails with a validation error indicating kebab-case is required

### Requirement: Resource Naming Convention
All AWS resources SHALL follow the naming pattern `{deployment_name}-{resource_type}-{environment}` using kebab-case.

#### Scenario: Compute resources follow naming convention
- **WHEN** deployment deploys compute resources
- **THEN** EC2 instance is tagged `{deployment}-allocator-{env}`
- **AND** Key pair is named `{deployment}-keypair-{env}`

#### Scenario: Networking resources follow naming convention
- **WHEN** deployment deploys networking resources
- **THEN** ALB is named `{deployment}-alb-{env}`
- **AND** Target group is named `{deployment}-alb-tg-{env}`
- **AND** Security groups are named `{deployment}-allocator-sg-{env}` and `{deployment}-alb-sg-{env}`
- **AND** Elastic IP is tagged `{deployment}-eip-{env}`

#### Scenario: IAM resources follow naming convention
- **WHEN** deployment deploys IAM resources
- **THEN** Instance role is named `{deployment}-allocator-role-{env}`
- **AND** Lambda role is named `{deployment}-lambda-role-{env}`
- **AND** Instance profile is named `{deployment}-allocator-profile-{env}`
- **AND** Policies are named `{deployment}-{policy-purpose}-policy-{env}`

#### Scenario: Monitoring resources follow naming convention
- **WHEN** deployment deploys monitoring resources
- **THEN** SNS topic is named `{deployment}-alerts-topic-{env}`
- **AND** CloudWatch alarms are named `{deployment}-alarm-{alarm-type}-{env}`
- **AND** Metric filters are named `{deployment}-metric-{metric-type}-{env}`

#### Scenario: Storage resources follow naming convention
- **WHEN** deployment deploys storage resources
- **THEN** S3 bucket is named `{deployment}-cloudtrail-bucket-{env}-{account_id}`
- **AND** CloudWatch log groups are named `{deployment}-{log-purpose}-logs-{env}`

#### Scenario: Lambda resources follow naming convention
- **WHEN** deployment deploys Lambda resources
- **THEN** Lambda function is named `{deployment}-log-processor-{env}`
- **AND** Lambda log group follows AWS path convention `/aws/lambda/{deployment}-log-processor-{env}`

### Requirement: Resource Tagging
All taggable AWS resources SHALL include a standard set of tags for cost allocation and resource management.

#### Scenario: All resources have required tags
- **WHEN** any taggable resource is created
- **THEN** resource has tag `Name` matching the resource name
- **AND** resource has tag `Environment` matching `var.environment`
- **AND** resource has tag `Project` matching `var.deployment_name`
- **AND** resource has tag `ManagedBy` with value `terraform`

#### Scenario: Optional repository tag
- **WHEN** `var.repository` is provided
- **THEN** all resources have tag `Repository` with the provided value

#### Scenario: Route53 records have tags
- **WHEN** Route53 records are created
- **THEN** records have all standard tags (Name, Environment, Project, ManagedBy)

#### Scenario: Query resources by project tag
- **WHEN** AWS CLI command `aws resourcegroupstaggingapi get-resources --tag-filters Key=Project,Values={deployment_name}` is executed
- **THEN** all resources for the deployment are returned

### Requirement: Multi-Deployment Isolation
Multiple deployments SHALL coexist in the same AWS account without resource name conflicts.

#### Scenario: Two deployments in same account
- **WHEN** `sleap-lablink` deployment exists in `prod` environment
- **AND** `deeplabcut-lablink` deployment is created in `prod` environment
- **THEN** both deployments succeed without name conflicts
- **AND** resources are independently manageable

#### Scenario: Same deployment across environments
- **WHEN** `sleap-lablink` deployment exists in `prod` environment
- **AND** `sleap-lablink` deployment is created in `dev` environment
- **THEN** both deployments succeed without name conflicts
- **AND** resources are independently manageable

#### Scenario: Terraform state isolation
- **WHEN** multiple deployments exist
- **THEN** each deployment has separate Terraform state file
- **AND** operations on one deployment do not affect others

## MODIFIED Requirements

### Requirement: DNS Configuration
The system SHALL accept full domain names in dns.domain and support sub-subdomains without pattern-based construction.

#### Scenario: Full domain specified
- **WHEN** dns.domain="lablink.sleap.ai"
- **THEN** Route53 A record is created for "lablink.sleap.ai" (exact match)

#### Scenario: Sub-subdomain specified
- **WHEN** dns.domain="test.lablink.sleap.ai"
- **THEN** Route53 A record is created for "test.lablink.sleap.ai" (exact match)

#### Scenario: Zone lookup matches exact domain
- **WHEN** dns.zone_id="" AND dns.domain="lablink.sleap.ai"
- **THEN** Terraform looks up hosted zone for "lablink.sleap.ai." (exact match only)

#### Scenario: DNS records have standard tags
- **WHEN** Route53 records are created with dns.terraform_managed=true
- **THEN** records include Project, Environment, and ManagedBy tags