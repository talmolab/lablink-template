# Development Commands Specification

## Purpose

This specification defines Claude Code development commands for validating, reviewing, and managing code.

## Requirements

### Requirement: Terraform Validation Command
The system MUST provide a `/validate-terraform` command that validates Terraform formatting and syntax.

#### Scenario: Developer validates Terraform before committing
- **GIVEN** working on infrastructure changes in lablink-infrastructure/
- **WHEN** invoking /validate-terraform
- **THEN** Claude runs terraform fmt -check on all .tf files
- **AND** Claude runs terraform validate with proper initialization
- **AND** Claude reports formatting or syntax errors with file:line references

### Requirement: YAML Configuration Validation Command
The system MUST provide a `/validate-yaml` command that validates config.yaml files against the lablink schema.

#### Scenario: Developer validates configuration changes
- **GIVEN** modified lablink-infrastructure/config/config.yaml
- **WHEN** invoking /validate-yaml
- **THEN** Claude runs lablink-validate-config on the config file
- **AND** Claude reports schema violations with clear error messages

### Requirement: Bash Script Validation Command
The system MUST provide a `/validate-bash` command that checks shell scripts for common errors and best practices.

#### Scenario: Developer validates shell script changes
- **GIVEN** modified lablink-infrastructure/user_data.sh
- **WHEN** invoking /validate-bash
- **THEN** Claude runs shellcheck on all .sh files
- **AND** Claude reports shellcheck findings by severity

### Requirement: Terraform Plan Command
The system MUST provide a /terraform-plan command that previews infrastructure changes for any environment.

#### Scenario: Developer previews infrastructure changes
- **GIVEN** on a feature branch with Terraform changes
- **WHEN** invoking /terraform-plan for ci-test environment
- **THEN** Claude initializes Terraform with backend-ci-test.hcl
- **AND** Claude runs terraform plan
- **AND** Claude summarizes resource changes

### Requirement: PR Review Command
The system MUST provide a /review-pr command that triggers thorough PR reviews with automated feedback.

#### Scenario: Developer reviews infrastructure PR
- **GIVEN** an open PR with Terraform changes
- **WHEN** invoking /review-pr <number>
- **THEN** Claude fetches PR details and comments
- **AND** Claude analyzes changes for best practices
- **AND** Claude checks for security issues
- **AND** Claude posts comprehensive review via gh CLI

### Requirement: PR Description Generation Command
The system MUST provide a /pr-description command that auto-generates structured PR descriptions from git history.

#### Scenario: Developer creates PR with generated description
- **GIVEN** on a feature branch with commits
- **WHEN** invoking /pr-description
- **THEN** Claude analyzes git diff against main branch
- **AND** Claude generates structured PR description with summary, changes, and checklist
- **AND** Claude formats output as markdown ready for GitHub

### Requirement: Changelog Update Command
The system MUST provide an /update-changelog command that maintains version history.

#### Scenario: Developer updates changelog before release
- **GIVEN** completed changes ready for release
- **WHEN** invoking /update-changelog
- **THEN** Claude analyzes commits since last release
- **AND** Claude updates CHANGELOG.md with categorized changes
- **AND** Claude follows keep-a-changelog format