# Development Commands Capability

**Domain:** Developer Tools
**Status:** Draft

## Overview

Commands that assist developers with validation, review, and quality checks during the development workflow.

## ADDED Requirements

### Requirement: Pre-Merge Validation Command

The development tooling SHALL provide a comprehensive pre-merge validation command that orchestrates all code quality checks, git status validation, PR analysis, and provides a clear merge readiness verdict.

**Rationale:** Developers need a single command that validates all merge prerequisites to prevent failed merges, unaddressed review comments, and quality issues. Manual execution of 5+ separate validation steps is error-prone, time-consuming, and leads to 20% of PRs being merged with issues. A comprehensive pre-merge check reduces failed merge attempts from 30% to <10%.

#### Scenario: Clean branch passes all checks

**Given** a feature branch with:
- All files properly formatted
- No merge conflicts with main
- All validation commands passing (Terraform, YAML, Bash)
- PR approved with all comments addressed
- CI checks passing

**When** developer runs `/pre-merge-check` in pre-merge mode

**Then** system SHALL:
- Execute all validation commands (Terraform, YAML, Bash)
- Check git status for conflicts
- Fetch PR metadata via `gh pr view`
- Verify PR is approved
- Verify CI checks are passing
- Fetch review comments via `gh api`
- Verify all comments are resolved
- Display "✅ READY TO MERGE" verdict
- Provide summary of successful checks
- Complete in < 10 minutes

#### Scenario: Merge conflicts detected before other checks

**Given** a feature branch with merge conflicts with origin/main

**When** developer runs `/pre-merge-check` in any mode

**Then** system SHALL:
- Run `git fetch origin main`
- Detect merge conflicts using `git merge-tree`
- Report conflicting files with paths
- Display "⛔ NOT READY TO MERGE" verdict
- Suggest conflict resolution steps:
  ```
  git fetch origin main
  git merge origin/main
  # Resolve conflicts in editor
  git add <resolved-files>
  git commit
  ```
- Skip expensive PR validation checks (no point if conflicts exist)
- Exit with non-zero status code

#### Scenario: Terraform validation failures block merge

**Given** a feature branch with Terraform formatting errors in 3 files

**When** developer runs `/pre-merge-check` in pre-pr or pre-merge mode

**Then** system SHALL:
- Execute `/validate-terraform` command
- Capture terraform fmt -check output
- Parse error output for file paths
- Report specific files with errors:
  ```
  ⛔ Terraform Validation Failed

  Formatting errors in 3 files:
    - lablink-infrastructure/main.tf
    - lablink-infrastructure/variables.tf
    - lablink-infrastructure/outputs.tf
  ```
- Display "⛔ NOT READY TO MERGE" verdict
- Suggest running `terraform fmt` to auto-fix
- Continue checking other validations (report all issues)
- Exit with non-zero status code

#### Scenario: Critical unaddressed Copilot comments block merge

**Given** a PR with 10 unaddressed GitHub Copilot review comments including:
- **SECURITY** issue: Unquoted variable in user_data.sh:49
- **CRITICAL** syntax error: Missing brace in main.tf:299
- 8 other suggestions

**When** developer runs `/pre-merge-check` in pre-merge mode

**Then** system SHALL:
- Fetch all PR comments via `gh api repos/:owner/:repo/pulls/:number/comments`
- Filter comments where `user.login == "copilot"`
- Detect 10 unresolved comments (no reply or resolution)
- Categorize by severity (SECURITY, CRITICAL, normal)
- List each comment with file:line reference:
  ```
  ⛔ Unaddressed Review Comments (10)

  SECURITY (1):
    • user_data.sh:49 - Quote variable to prevent injection

  CRITICAL (1):
    • main.tf:299 - Add missing closing brace [SYNTAX ERROR]

  Suggestions (8):
    • README.md:241 - Remove duplicate rate limit line
    • main.tf:307 - Clarify DNS zone trailing dot
    • main.tf:298 - Document parent zone lookup edge case
    ... (5 more)
  ```
- Display "⛔ NOT READY TO MERGE" verdict
- Suggest addressing all comments before merge
- Exit with non-zero status code

#### Scenario: CI checks failing block merge

**Given** a PR with 2 failing CI status checks:
- `Terraform Format` - Failing
- `Config Validation` - Passing

**When** developer runs `/pre-merge-check` in pre-merge mode

**Then** system SHALL:
- Fetch PR status via `gh pr view --json statusCheckRollup`
- Parse status check results
- Identify failing checks
- Report specific failures:
  ```
  ⛔ CI Checks Failing (1 of 2)

  ❌ Terraform Format - FAILED
  ✅ Config Validation - PASSED
  ```
- Display "⛔ NOT READY TO MERGE" verdict
- Suggest fixing CI failures before merge
- Provide link to CI run for details
- Exit with non-zero status code

#### Scenario: No CI checks configured (edge case)

**Given** a PR with no CI status checks running (statusCheckRollup is empty)

**When** developer runs `/pre-merge-check` in pre-merge mode

**Then** system SHALL:
- Detect zero status checks
- Display warning (not error):
  ```
  ⚠️  NO CI CHECKS RUNNING

  This may indicate:
    - Workflows not configured for this branch
    - Branch protection not set up
    - First-time branch (workflows haven't triggered)

  Manual verification required before merge.
  ```
- NOT fail the pre-merge check (warning only)
- Continue with other validations
- Include warning in final summary

#### Scenario: Fast local mode skips expensive checks

**Given** developer wants quick validation before pushing

**When** developer runs `/pre-merge-check local`

**Then** system SHALL:
- Run git status checks only:
  - Uncommitted changes check
  - Merge conflict detection
  - Branch divergence check
- Run fast format checks:
  - `terraform fmt -check` (no full validate)
  - Skip YAML validation (slower, Docker-based)
  - Skip Bash validation
- Skip PR analysis (no gh CLI calls)
- Skip OpenSpec validation
- Complete in < 2 minutes
- Provide limited verdict based on fast checks only
- Exit with appropriate status code

#### Scenario: OpenSpec changes trigger additional validation

**Given** a PR that modifies files in `openspec/changes/` directory

**When** developer runs `/pre-merge-check` in pre-pr or pre-merge mode

**Then** system SHALL:
- Detect OpenSpec changes via `git diff --name-only origin/main...HEAD | grep "^openspec/"`
- Run `openspec validate --strict`
- Check if any breaking changes are proposed
- Verify proposal exists for breaking changes
- Report OpenSpec validation results:
  ```
  OpenSpec Validation:
    ✅ Change 'add-pre-merge-validation' is valid
    ✅ All specs conform to schema
    ✅ No breaking changes without proposals
  ```
- Include in overall verdict
- If OpenSpec validation fails, block merge

#### Scenario: Mode selection via parameter

**Given** developer can specify execution mode

**When** developer runs command with mode parameter

**Then** system SHALL:
- `/pre-merge-check local` - Run local mode (1-2 min)
- `/pre-merge-check pre-pr` - Run pre-pr mode (3-5 min)
- `/pre-merge-check pre-merge` - Run pre-merge mode (5-10 min)
- `/pre-merge-check` (no param) - Default to pre-merge mode
- Validate mode parameter is valid
- Report which mode is running at start
- Execute appropriate subset of checks

### Requirement: .claude Directory Version Control

The .claude directory containing Claude commands SHALL be tracked in version control to ensure consistent command availability across all developers and enable command review through PR process.

**Rationale:** Currently .claude/ is gitignored, meaning commands are not versioned, developers have inconsistent command availability, and command updates don't flow through PR review process. Tracking commands as code ensures: consistent developer experience, versioned command history, peer review of command changes, and automatic command distribution to new developers.

#### Scenario: .claude directory is tracked in git

**Given** repository with .claude/ directory containing commands

**When** checking git tracking status

**Then** system SHALL:
- `.claude/` NOT be in .gitignore
- `.claude/commands/` files be tracked by git
- `.claude/settings.local.json` be in .gitignore (personal settings)
- `git ls-files .claude/` return tracked files
- `git status` show .claude/ changes in working tree

#### Scenario: Command changes go through PR review

**Given** developer modifies a command in .claude/commands/

**When** developer creates a PR

**Then** system SHALL:
- Include .claude/ changes in git diff
- Show command modifications in PR file changes
- Enable code review of command changes
- Require approval before merging command updates
- Preserve command change history in git log

#### Scenario: New developers automatically get commands

**Given** new developer clones repository

**When** they run `git clone`

**Then** system SHALL:
- Include all .claude/commands/ files in clone
- Provide immediate access to all commands
- No manual command installation required
- Consistent command availability across team

#### Scenario: Personal settings remain local

**Given** developer has personal Claude settings in .claude/settings.local.json

**When** checking git status

**Then** system SHALL:
- NOT track .claude/settings.local.json (gitignored)
- NOT include personal settings in commits
- Allow each developer to maintain personal preferences
- Share commands but not settings

### Requirement: Clear Pre-Merge Reporting

The pre-merge validation command SHALL provide clear, actionable output with color-coded sections, progress indicators, and specific remediation steps for each type of failure.

**Rationale:** With 5+ categories of checks, generic error messages are unhelpful. Developers need to quickly identify: what failed, why it failed, and how to fix it. Clear reporting reduces debugging time and speeds up PR resolution.

#### Scenario: Success report shows summary

**Given** all pre-merge checks pass

**When** command completes

**Then** system SHALL:
- Display clear success indicator: "✅ READY TO MERGE"
- List all checks that passed:
  ```
  ✅ READY TO MERGE

  All checks passed:
    ✅ No merge conflicts
    ✅ Working tree clean
    ✅ Terraform validation passed
    ✅ YAML validation passed
    ✅ Bash validation passed
    ✅ PR approved by 2 reviewers
    ✅ CI checks passing (2/2)
    ✅ All review comments addressed

  Execution time: 4m 32s
  You can safely merge this PR.
  ```
- Use green color for success (if terminal supports)
- Show execution time
- Exit with status code 0

#### Scenario: Failure report categorizes issues

**Given** multiple types of failures (git conflicts, validation failures, unaddressed comments)

**When** command completes

**Then** system SHALL:
- Display clear failure indicator: "⛔ NOT READY TO MERGE"
- Group failures by category:
  ```
  ⛔ NOT READY TO MERGE

  Blocking issues found:

  1. MERGE CONFLICTS (2 files)
     Files in conflict:
       • lablink-infrastructure/main.tf
       • README.md

     Action Required:
       git fetch origin main
       git merge origin/main
       # Resolve conflicts
       git commit

  2. VALIDATION FAILURES (1)
     ❌ Terraform:
       • main.tf:299 - Syntax error (missing closing brace)

     Action Required:
       Fix syntax error and run terraform validate

  3. UNADDRESSED REVIEW COMMENTS (10)
     [SECURITY] user_data.sh:49 - Quote variable
     [CRITICAL] main.tf:256 - Empty DOMAIN_NAME
     ... (8 more)

     Action Required:
       Address all Copilot comments or reply with rationale

  Do not merge until all issues are resolved.
  Run `/pre-merge-check` again after fixes.
  ```
- Use red color for failures (if terminal supports)
- Number each category
- Provide specific remediation steps
- Exit with non-zero status code

#### Scenario: Progress indicators for long operations

**Given** command is running expensive checks (validation, API calls)

**When** checks are executing

**Then** system SHALL:
- Display progress for each phase:
  ```
  🔍 Pre-Merge Validation (mode: pre-merge)

  [1/5] Git Status Checks...
    ✅ No uncommitted changes
    ✅ No merge conflicts
    ⏳ Checking branch divergence...

  [2/5] Code Quality Validation...
    ⏳ Running terraform validation...
  ```
- Use spinner or progress bar for long operations
- Show which check is currently running
- Provide time estimates if possible
- Keep user informed (avoid appearing hung)

#### Scenario: Actionable error messages with file:line references

**Given** validation failures in specific files

**When** reporting failures

**Then** system SHALL:
- Include file:line references in clickable format:
  ```
  ❌ Validation Failures:
    • main.tf:299 - Missing closing brace
    • user_data.sh:49 - Unquoted variable $DOMAIN_NAME
    • README.md:241 - Duplicate line
  ```
- Use format that VSCode can parse and make clickable
- Provide enough context to locate the issue
- Include error message from underlying tool
- Suggest specific fix when possible

## MODIFIED Requirements

None. This is a new capability with no modifications to existing requirements.

## REMOVED Requirements

None. This is purely additive functionality.

## Related Capabilities

**Terraform Validation** - Orchestrated by pre-merge check
**YAML Validation** - Orchestrated by pre-merge check
**Bash Validation** - Orchestrated by pre-merge check
**PR Review** - /review-pr command provides detailed review, pre-merge check ensures it's addressed
**OpenSpec Workflow** - OpenSpec validation integrated into pre-merge checks

## Dependencies

**Existing Commands:**
- /validate-terraform - Terraform validation
- /validate-yaml - YAML config validation
- /validate-bash - Bash script validation

**External Tools:**
- git CLI - Status checks and conflict detection
- gh CLI - PR metadata and comment analysis
- openspec CLI - OpenSpec validation

**GitHub API:**
- Pull request metadata
- Review comments
- Status checks
- Approval status

## References

- [gh CLI manual](https://cli.github.com/manual/) - PR analysis tool
- [OpenSpec validation](https://github.com/openspec-framework/openspec) - Spec validation
- [Git merge-tree](https://git-scm.com/docs/git-merge-tree) - Conflict detection without checkout