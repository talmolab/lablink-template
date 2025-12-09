# Development Commands Specification

## ADDED Requirements

### Requirement: Developers can validate Terraform code via Claude command

The system MUST provide a `/validate-terraform` command that validates Terraform formatting and syntax without requiring developers to remember complex CLI commands.

#### Scenario: Developer validates Terraform before committing

```gherkin
Given I am working on infrastructure changes in lablink-infrastructure/
When I invoke /validate-terraform
Then Claude runs terraform fmt -check on all .tf files
And Claude runs terraform validate with proper initialization
And Claude reports any formatting or syntax errors with file:line references
And Claude provides fix suggestions for common errors
```

### Requirement: Developers can validate YAML configuration via Claude command

The system MUST provide a `/validate-yaml` command that validates config.yaml files against the lablink schema.

#### Scenario: Developer validates configuration changes

```gherkin
Given I modified lablink-infrastructure/config/config.yaml
When I invoke /validate-yaml
Then Claude runs lablink-validate-config on the config file
And Claude reports schema violations with clear error messages
And Claude suggests fixes based on example configs
```

### Requirement: Developers can validate Bash scripts via Claude command

The system MUST provide a `/validate-bash` command that checks shell scripts for common errors and best practices.

#### Scenario: Developer validates shell script changes

```gherkin
Given I modified lablink-infrastructure/user_data.sh
When I invoke /validate-bash
Then Claude runs shellcheck on all .sh files
And Claude reports shellcheck findings by severity (error, warning, info)
And Claude provides fix examples for common issues
And Claude links to shellcheck wiki for detailed explanations
```

### Requirement: Developers can generate Terraform plans via Claude command

The system MUST provide a /terraform-plan command that previews infrastructure changes for any environment.

#### Scenario: Developer previews infrastructure changes for ci-test

```gherkin
Given I am on a feature branch with Terraform changes
When I invoke /terraform-plan for ci-test environment
Then Claude initializes Terraform with backend-ci-test.hcl
And Claude runs terraform plan
And Claude summarizes resource changes (additions, modifications, deletions)
And Claude highlights potential cost or security implications
```

### Requirement: Developers can review PRs comprehensively via Claude command

The system MUST provide a /review-pr command that triggers thorough PR reviews with automated feedback.

#### Scenario: Developer reviews infrastructure PR

```gherkin
Given there is an open PR #25 with Terraform changes
When I invoke /review-pr 25
Then Claude fetches PR details and all comments
And Claude analyzes changes for infrastructure best practices
And Claude checks for security issues (IAM policies, security groups, public access)
And Claude validates Terraform formatting and structure
And Claude posts comprehensive review via gh CLI
And the review includes categorized feedback (critical, important, minor)
```

### Requirement: Developers can generate PR descriptions via Claude command

The system MUST provide a /pr-description command that auto-generates structured PR descriptions from git history.

#### Scenario: Developer creates PR with generated description

```gherkin
Given I am on a feature branch with multiple commits
When I invoke /pr-description
Then Claude analyzes git diff against main branch
And Claude reviews commit messages for context
And Claude generates structured PR description with:
  - Summary of changes
  - Infrastructure resources modified
  - Configuration changes
  - Security implications
  - Testing checklist
  - Related issues
And Claude formats output as markdown ready for GitHub
```

### Requirement: Developers can trigger deployments via Claude command

The system MUST provide deployment commands that deploy infrastructure to test environments safely.

#### Scenario: Developer deploys to ci-test environment

```gherkin
Given I want to deploy my changes to ci-test
When I invoke /deploy-test
Then Claude triggers the terraform-deploy.yml GitHub Actions workflow
And Claude passes ci-test as the environment parameter
And Claude monitors deployment progress with gh run watch
And Claude reports deployment status (success/failure)
And Claude provides CloudWatch logs URL if deployment fails
```

### Requirement: Developers can destroy infrastructure safely via Claude command

The system MUST provide a /destroy-infrastructure command that tears down test environments with safety checks.

#### Scenario: Developer destroys ci-test infrastructure

```gherkin
Given I want to clean up ci-test environment
When I invoke /destroy-infrastructure for ci-test
Then Claude confirms the environment name
And Claude warns about data loss (S3 state, DynamoDB locks)
And Claude requires explicit confirmation
And Claude triggers terraform-destroy.yml workflow
And Claude monitors destruction progress
And Claude verifies all resources were destroyed
```

### Requirement: Developers can check infrastructure health via Claude command

The system MUST provide a /check-infrastructure command that verifies deployed infrastructure is functioning.

#### Scenario: Developer checks ci-test deployment health

```gherkin
Given infrastructure is deployed to ci-test
When I invoke /check-infrastructure for ci-test
Then Claude performs HTTP connectivity test to allocator
And Claude validates DNS resolution (if DNS enabled)
And Claude checks SSL certificate validity (if HTTPS enabled)
And Claude queries EC2 instance status via AWS CLI
And Claude reports overall health status (healthy/degraded/down)
And Claude provides troubleshooting steps for any failures
```

### Requirement: Developers can view CloudWatch logs via Claude command

The system MUST provide a /view-logs command that fetches and filters CloudWatch logs for debugging.

#### Scenario: Developer views recent allocator logs

```gherkin
Given allocator is running in ci-test
When I invoke /view-logs for allocator in ci-test
Then Claude uses AWS CLI to fetch CloudWatch log streams
And Claude presents log entries with timestamps
And Claude supports time range filtering (last 1h, last 24h, custom)
And Claude highlights errors and warnings in the output
```

### Requirement: Developers can build Docker images via Claude command

The system MUST provide Docker build commands that build and tag Docker images for testing.

#### Scenario: Developer builds allocator Docker image locally

```gherkin
Given I modified allocator application code
When I invoke /docker-build-allocator
Then Claude runs docker build with appropriate tag
And Claude reports build progress and final image size
And Claude verifies image builds successfully
And Claude provides docker run command for local testing
And Claude documents GHCR push steps for publishing
```

### Requirement: Developers can update changelog via Claude command

The system MUST provide a /update-changelog command that generates changelog entries from git history.

#### Scenario: Developer updates CHANGELOG for release

```gherkin
Given I am preparing a release with multiple PRs merged
When I invoke /update-changelog
Then Claude analyzes git log since last release tag
And Claude categorizes changes (Added, Changed, Fixed, Security, Infrastructure)
And Claude generates changelog entries with PR references
And Claude follows Keep a Changelog format
And Claude prepends entries to CHANGELOG.md
```

### Requirement: Command documentation is discoverable and comprehensive

All commands MUST be well-documented with examples and troubleshooting guidance.

#### Scenario: Developer discovers available commands

```gherkin
Given I am new to lablink-template development
When I navigate to .claude/commands/ directory
Then I see a README.md listing all available commands
And each command has its own .md file with:
  - Clear description of purpose
  - Usage syntax and examples
  - Expected output
  - Troubleshooting section
  - Related commands
And commands are organized by category (validation, deployment, monitoring)
```

### Requirement: Commands integrate with existing tools and workflows

Commands MUST use standard tools already in the project ecosystem.

#### Scenario: Command uses GitHub CLI for PR operations

```gherkin
Given /review-pr command is invoked
When Claude needs to fetch PR data
Then Claude uses gh pr view, gh pr diff, and gh api commands
And Claude does not require additional authentication beyond gh auth
And Claude respects gh configuration (default repo, auth token)
```

#### Scenario: Command uses Terraform CLI with correct backend

```gherkin
Given /terraform-plan command is invoked for test environment
When Claude initializes Terraform
Then Claude uses terraform init with -backend-config=backend-test.hcl
And Claude respects Terraform version constraints from .terraform-version
And Claude uses existing Terraform binary from PATH
```

### Requirement: Commands provide actionable error messages and guidance

When commands fail, the system MUST provide clear guidance on how to resolve issues.

#### Scenario: Validation command fails with clear next steps

```gherkin
Given I invoke /validate-terraform with formatting errors
When Terraform validation fails
Then Claude reports exact files and line numbers with issues
And Claude shows the diff between current and expected formatting
And Claude provides the fix command (terraform fmt)
And Claude offers to run the fix automatically if requested
```