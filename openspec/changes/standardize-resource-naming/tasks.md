## 1. Variables and Locals Setup

- [ ] 1.1 Add `deployment_name` variable with validation (required, kebab-case pattern)
- [ ] 1.2 Rename `resource_suffix` to `environment` in variables
- [ ] 1.3 Add optional `repository` variable for traceability tag
- [ ] 1.4 Create `locals` block with:
  - [ ] 1.4.1 `name_prefix` = `var.deployment_name`
  - [ ] 1.4.2 `name_suffix` = `var.environment`
  - [ ] 1.4.3 `common_tags` map with standard tags
- [ ] 1.5 Run `terraform validate` to verify variable syntax

## 2. Resource Naming Updates (main.tf)

### 2.1 Compute Resources
- [ ] 2.1.1 Update `aws_key_pair` name: `{deployment}-keypair-{env}`
- [ ] 2.1.2 Update `aws_instance` tags: `{deployment}-allocator-{env}`
- [ ] 2.1.3 Update `aws_eip` tags: `{deployment}-eip-{env}`

### 2.2 Networking Resources
- [ ] 2.2.1 Update `aws_security_group` (allocator): `{deployment}-allocator-sg-{env}`
- [ ] 2.2.2 Add standard tags to all security groups

### 2.3 IAM Resources
- [ ] 2.3.1 Update `aws_iam_role` (instance): `{deployment}-allocator-role-{env}`
- [ ] 2.3.2 Update `aws_iam_role` (lambda): `{deployment}-lambda-role-{env}`
- [ ] 2.3.3 Update `aws_iam_policy` (S3): `{deployment}-s3-backend-policy-{env}`
- [ ] 2.3.4 Update `aws_iam_policy` (EC2): `{deployment}-ec2-mgmt-policy-{env}`
- [ ] 2.3.5 Update `aws_iam_instance_profile`: `{deployment}-allocator-profile-{env}`
- [ ] 2.3.6 Add standard tags to all IAM resources

### 2.4 Lambda Resources
- [ ] 2.4.1 Update `aws_lambda_function`: `{deployment}-log-processor-{env}`
- [ ] 2.4.2 Update `aws_cloudwatch_log_group` (lambda): `/aws/lambda/{deployment}-log-processor-{env}`
- [ ] 2.4.3 Update `aws_cloudwatch_log_subscription_filter` name
- [ ] 2.4.4 Add standard tags to Lambda resources

### 2.5 CloudWatch Log Groups
- [ ] 2.5.1 Update client VM log group: `{deployment}-client-logs-{env}`
- [ ] 2.5.2 Add standard tags to log groups

### 2.6 Route53 Records
- [ ] 2.6.1 Add standard tags to `aws_route53_record` (allocator)
- [ ] 2.6.2 Add standard tags to `aws_route53_record` (ALB)

## 3. Resource Naming Updates (alb.tf)

- [ ] 3.1 Update `aws_security_group` (ALB): `{deployment}-alb-sg-{env}`
- [ ] 3.2 Update `aws_lb`: `{deployment}-alb-{env}`
- [ ] 3.3 Update `aws_lb_target_group`: `{deployment}-alb-tg-{env}`
- [ ] 3.4 Add standard tags to all ALB resources

## 4. Resource Naming Updates (cloudtrail.tf)

- [ ] 4.1 Update `aws_s3_bucket`: `{deployment}-cloudtrail-bucket-{env}-{account_id}`
- [ ] 4.2 Update `aws_cloudwatch_log_group`: `{deployment}-cloudtrail-logs-{env}`
- [ ] 4.3 Update `aws_iam_role` (cloudtrail): `{deployment}-cloudtrail-role-{env}`
- [ ] 4.4 Update `aws_cloudtrail`: `{deployment}-cloudtrail-{env}`
- [ ] 4.5 Add standard tags to all CloudTrail resources

## 5. Resource Naming Updates (cloudwatch_alarms.tf)

- [ ] 5.1 Update `aws_sns_topic`: `{deployment}-alerts-topic-{env}`
- [ ] 5.2 Update metric filters:
  - [ ] 5.2.1 `{deployment}-metric-run-instances-{env}`
  - [ ] 5.2.2 `{deployment}-metric-large-instances-{env}`
  - [ ] 5.2.3 `{deployment}-metric-unauthorized-{env}`
  - [ ] 5.2.4 `{deployment}-metric-termination-{env}`
- [ ] 5.3 Update alarms:
  - [ ] 5.3.1 `{deployment}-alarm-mass-launch-{env}`
  - [ ] 5.3.2 `{deployment}-alarm-large-instance-{env}`
  - [ ] 5.3.3 `{deployment}-alarm-unauthorized-{env}`
  - [ ] 5.3.4 `{deployment}-alarm-termination-{env}`
- [ ] 5.4 Update CloudWatch namespace: `{deployment}Security/{env}`
- [ ] 5.5 Add standard tags to all monitoring resources

## 6. Resource Naming Updates (budget.tf)

- [ ] 6.1 Update `aws_budgets_budget`: `{deployment}-monthly-budget-{env}`
- [ ] 6.2 Add standard tags to budget resource

## 7. Configuration Updates

- [ ] 7.1 Update `backend-*.hcl` files with new variable documentation
- [ ] 7.2 Update example config files:
  - [ ] 7.2.1 Add `deployment_name` to `config/prod.example.yaml`
  - [ ] 7.2.2 Add `deployment_name` to `config/ip-only.example.yaml`
- [ ] 7.3 Update any hardcoded `lablink-eip` references in config

## 8. CI/CD Updates

- [ ] 8.1 Update GitHub Actions workflows to pass `deployment_name`
- [ ] 8.2 Update destroy workflow with new variable
- [ ] 8.3 Add `deployment_name` to workflow inputs where applicable

## 9. Documentation Updates

- [ ] 9.1 Update `openspec/project.md` with new naming convention
- [ ] 9.2 Update backend-*.hcl header comments with new pattern
- [ ] 9.3 Add migration guide to release notes

## 10. Validation and Testing

- [ ] 10.1 Run `terraform fmt` on all .tf files
- [ ] 10.2 Run `terraform validate` to check syntax
- [ ] 10.3 Run `terraform plan` with test configuration to verify:
  - [ ] 10.3.1 All resources have correct naming pattern
  - [ ] 10.3.2 All resources have standard tags
  - [ ] 10.3.3 No hardcoded `lablink-` prefixes remain
- [ ] 10.4 Verify tag query works:
  ```bash
  aws resourcegroupstaggingapi get-resources --tag-filters Key=Project,Values={deployment_name}
  ```
- [ ] 10.5 Test multi-deployment scenario (if possible in ci-test)

## 11. Final Verification

- [ ] 11.1 Search codebase for remaining `lablink_` (underscore) patterns
- [ ] 11.2 Search codebase for remaining hardcoded `lablink-` prefixes
- [ ] 11.3 Verify all resources in terraform plan use new naming
- [ ] 11.4 Update GitHub issue #28 with completion status