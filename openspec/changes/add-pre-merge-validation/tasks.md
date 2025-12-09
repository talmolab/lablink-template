# Implementation Tasks: Add Pre-Merge Validation

## Phase 1: Repository Preparation

- [ ] Remove .claude/ from .gitignore
  - [ ] Edit .gitignore and remove line 233 (`.claude/`)
  - [ ] Add `.claude/settings.local.json` to .gitignore (personal settings)
  - [ ] Verify .claude/commands/ will be tracked

- [ ] Commit .claude directory to repository
  - [ ] Run `git add .claude/`
  - [ ] Run `git add .gitignore`
  - [ ] Commit with message: "Track .claude commands in version control"
  - [ ] Push to remote

- [ ] Verify .claude tracking works
  - [ ] Check `git ls-files .claude/` shows tracked files
  - [ ] Verify .claude/ appears in GitHub repository
  - [ ] Test that new clone includes .claude/

## Phase 2: Core Command Structure

- [ ] Create command file
  - [ ] Create `.claude/commands/pre-merge-check.md`
  - [ ] Add command description and purpose
  - [ ] Define command template with mode parameter
  - [ ] Document execution modes (local, pre-pr, pre-merge)

- [ ] Implement mode selection logic
  - [ ] Parse mode parameter from user input
  - [ ] Validate mode is one of: local, pre-pr, pre-merge
  - [ ] Default to pre-merge if no mode specified
  - [ ] Report which mode is running

## Phase 3: Git Status Validation

- [ ] Implement uncommitted changes check
  - [ ] Run `git status --porcelain`
  - [ ] Parse output for uncommitted changes
  - [ ] Report files with uncommitted changes
  - [ ] Provide remediation suggestion

- [ ] Implement merge conflict detection
  - [ ] Run `git fetch origin main`
  - [ ] Run `git merge-tree` to detect conflicts without modifying working tree
  - [ ] Parse merge-tree output for conflicts
  - [ ] Extract conflicting file paths
  - [ ] Report conflicts with clear file list
  - [ ] Suggest conflict resolution steps
  - [ ] If conflicts found, skip expensive checks and exit

- [ ] Implement branch divergence check
  - [ ] Run `git rev-list --left-right --count HEAD...origin/main`
  - [ ] Parse output for commits ahead/behind
  - [ ] Report branch status (ahead, behind, diverged)
  - [ ] Suggest sync steps if diverged

- [ ] Test git status checks
  - [ ] Test with clean branch (should pass)
  - [ ] Test with uncommitted changes (should report)
  - [ ] Test with merge conflicts (should detect and block)
  - [ ] Test with diverged branch (should report)

## Phase 4: Validation Orchestration

- [ ] Implement /validate-terraform invocation
  - [ ] Call /validate-terraform command
  - [ ] Capture output and exit code
  - [ ] Parse terraform errors for file:line references
  - [ ] Store results for aggregation

- [ ] Implement /validate-yaml invocation
  - [ ] Call /validate-yaml command
  - [ ] Capture output and exit code
  - [ ] Parse validation errors
  - [ ] Store results for aggregation

- [ ] Implement /validate-bash invocation
  - [ ] Call /validate-bash command
  - [ ] Capture output and exit code
  - [ ] Parse shellcheck errors for file:line references
  - [ ] Store results for aggregation

- [ ] Implement validation result aggregation
  - [ ] Collect results from all validation commands
  - [ ] Categorize by type (Terraform, YAML, Bash)
  - [ ] Count total failures
  - [ ] Prepare for reporting

- [ ] Implement mode-based validation filtering
  - [ ] Local mode: Skip YAML and Bash validation (only terraform fmt -check)
  - [ ] Pre-PR mode: Run all validations
  - [ ] Pre-merge mode: Run all validations

- [ ] Test validation orchestration
  - [ ] Test with all validations passing
  - [ ] Test with Terraform failures
  - [ ] Test with YAML failures
  - [ ] Test with Bash failures
  - [ ] Test with multiple failures
  - [ ] Verify exit codes propagate correctly

## Phase 5: PR Analysis (Pre-Merge Mode Only)

- [ ] Implement gh CLI availability check
  - [ ] Check if `gh` command exists
  - [ ] Verify gh authentication status
  - [ ] If not available, skip PR checks with warning
  - [ ] Provide installation instructions if missing

- [ ] Implement PR metadata fetching
  - [ ] Determine current PR number (from branch or parameter)
  - [ ] Run `gh pr view --json number,state,title,author`
  - [ ] Parse JSON output
  - [ ] Handle error if PR not found
  - [ ] Store PR metadata for checks

- [ ] Implement approval status check
  - [ ] Run `gh pr view --json reviews`
  - [ ] Parse review data for approval status
  - [ ] Count number of approvals
  - [ ] Check if approval requirement met
  - [ ] Report approval status

- [ ] Implement CI status check
  - [ ] Run `gh pr view --json statusCheckRollup`
  - [ ] Parse status check results
  - [ ] Identify passing vs failing checks
  - [ ] Handle edge case: no CI checks configured
  - [ ] Report CI status with check names

- [ ] Implement review comment fetching
  - [ ] Run `gh api repos/:owner/:repo/pulls/:number/comments`
  - [ ] Parse JSON output for comment data
  - [ ] Extract file, line, body, and author for each comment
  - [ ] Handle pagination if many comments exist

- [ ] Implement Copilot comment filtering
  - [ ] Filter comments where `user.login` contains "copilot"
  - [ ] Identify Copilot-generated comments
  - [ ] Extract severity keywords (SECURITY, CRITICAL, etc.)
  - [ ] Categorize by severity

- [ ] Implement comment resolution detection
  - [ ] Check if comment has `in_reply_to_id` (replied to)
  - [ ] Check if comment is marked as resolved
  - [ ] Identify unresolved comments
  - [ ] Count unresolved by category

- [ ] Test PR analysis
  - [ ] Test with approved PR
  - [ ] Test with unapproved PR
  - [ ] Test with failing CI checks
  - [ ] Test with no CI checks
  - [ ] Test with Copilot comments (resolved and unresolved)
  - [ ] Test with PR not found
  - [ ] Test with gh CLI not installed

## Phase 6: OpenSpec Integration

- [ ] Implement OpenSpec change detection
  - [ ] Run `git diff --name-only origin/main...HEAD`
  - [ ] Filter for paths matching `openspec/`
  - [ ] Determine if OpenSpec validation needed

- [ ] Implement openspec validate invocation
  - [ ] Run `openspec validate --strict`
  - [ ] Capture output and exit code
  - [ ] Parse validation results
  - [ ] Handle OpenSpec not installed gracefully

- [ ] Implement breaking change detection
  - [ ] Check if proposal contains breaking changes
  - [ ] Verify proposal exists for breaking changes
  - [ ] Report breaking changes without proposals

- [ ] Test OpenSpec integration
  - [ ] Test with no OpenSpec changes (skip validation)
  - [ ] Test with valid OpenSpec changes
  - [ ] Test with invalid OpenSpec changes
  - [ ] Test with breaking changes without proposal

## Phase 7: Reporting and UX

- [ ] Design output format structure
  - [ ] Define sections: header, checks, verdict, summary
  - [ ] Choose color scheme (green=pass, red=fail, yellow=warn)
  - [ ] Design progress indicator format
  - [ ] Plan file:line reference format (VSCode-clickable)

- [ ] Implement verdict logic
  - [ ] If any blocking issue found: "⛔ NOT READY TO MERGE"
  - [ ] If all checks pass: "✅ READY TO MERGE"
  - [ ] Determine exit code (0=ready, 1=not ready)

- [ ] Implement success reporting
  - [ ] List all checks that passed
  - [ ] Show execution time
  - [ ] Display "Ready to Merge" verdict
  - [ ] Provide congratulatory message

- [ ] Implement failure reporting
  - [ ] Group failures by category (conflicts, validations, comments, CI)
  - [ ] Number each category
  - [ ] List specific failures with file:line
  - [ ] Show unaddressed comment count and examples
  - [ ] Display "Not Ready" verdict
  - [ ] Provide remediation suggestions

- [ ] Implement progress indicators
  - [ ] Show phase number and name (e.g., "[1/5] Git Status Checks...")
  - [ ] Display spinner for long-running operations
  - [ ] Update status as checks complete
  - [ ] Show elapsed time periodically

- [ ] Implement action item listing
  - [ ] Extract actionable items from failures
  - [ ] Provide specific commands to run
  - [ ] Suggest next steps
  - [ ] Link to relevant documentation

- [ ] Test reporting
  - [ ] Test success report (all pass)
  - [ ] Test failure report (all fail)
  - [ ] Test mixed results
  - [ ] Verify colors display correctly (if supported)
  - [ ] Verify file:line references are clickable
  - [ ] Check readability in various terminals

## Phase 8: Error Handling

- [ ] Handle gh CLI not installed
  - [ ] Check for `gh` command availability
  - [ ] Display warning if not found
  - [ ] Provide installation instructions
  - [ ] Skip PR checks gracefully
  - [ ] Don't fail entire command

- [ ] Handle not in git repository
  - [ ] Check if `.git` directory exists
  - [ ] Display clear error message
  - [ ] Exit gracefully with helpful message
  - [ ] Suggest running from repository root

- [ ] Handle PR not found
  - [ ] Catch gh CLI error for invalid PR number
  - [ ] Display clear message: "No PR found for this branch"
  - [ ] Suggest creating PR or checking branch name
  - [ ] Skip PR validation gracefully

- [ ] Handle network failures
  - [ ] Catch network errors from gh CLI
  - [ ] Display timeout/connection error message
  - [ ] Suggest checking network connection
  - [ ] Retry option for transient failures

- [ ] Handle OpenSpec not installed
  - [ ] Check for `openspec` command availability
  - [ ] Display warning if not found
  - [ ] Skip OpenSpec validation
  - [ ] Suggest installation if OpenSpec changes detected

- [ ] Test error scenarios
  - [ ] Test without gh CLI installed
  - [ ] Test outside git repository
  - [ ] Test with invalid PR number
  - [ ] Test with network disconnected
  - [ ] Test without openspec installed
  - [ ] Verify clear error messages for each

## Phase 9: Documentation

- [ ] Write command usage documentation
  - [ ] Document command syntax
  - [ ] Explain three execution modes
  - [ ] List what each mode checks
  - [ ] Document execution times for each mode

- [ ] Add examples for each mode
  - [ ] Example: `/pre-merge-check local` (quick check)
  - [ ] Example: `/pre-merge-check pre-pr` (before PR creation)
  - [ ] Example: `/pre-merge-check pre-merge` (before merging)
  - [ ] Example: `/pre-merge-check` (default, same as pre-merge)
  - [ ] Show sample output for each

- [ ] Document common issues and fixes
  - [ ] Merge conflicts: How to resolve
  - [ ] Validation failures: How to fix
  - [ ] Unaddressed comments: How to handle
  - [ ] CI failures: How to debug
  - [ ] OpenSpec errors: How to resolve

- [ ] Add troubleshooting section
  - [ ] gh CLI authentication issues
  - [ ] Network connectivity problems
  - [ ] Command taking too long
  - [ ] False positives
  - [ ] How to override checks (with caution)

- [ ] Update README.md
  - [ ] Add section on pre-merge validation
  - [ ] Link to command documentation
  - [ ] Explain when to use command
  - [ ] Mention benefit (prevent failed merges)

- [ ] Update .claude/commands/README.md
  - [ ] List new /pre-merge-check command
  - [ ] Describe purpose and modes
  - [ ] Link to full documentation
  - [ ] Note that it orchestrates other commands

## Phase 10: Testing and Validation

- [ ] Test with clean branch (baseline)
  - [ ] Create clean branch from main
  - [ ] Run command in all three modes
  - [ ] Verify all checks pass
  - [ ] Verify "Ready to Merge" verdict
  - [ ] Check execution times are within limits

- [ ] Test with merge conflicts
  - [ ] Create branch with intentional conflicts
  - [ ] Run command
  - [ ] Verify conflicts detected and reported
  - [ ] Verify specific files listed
  - [ ] Verify command exits early (doesn't run expensive checks)

- [ ] Test with validation failures
  - [ ] Create branch with terraform formatting errors
  - [ ] Create branch with YAML validation errors
  - [ ] Create branch with shellcheck errors
  - [ ] Run command for each scenario
  - [ ] Verify failures reported with file:line references

- [ ] Test with unaddressed Copilot comments
  - [ ] Use PR #17 as test case (has 10 comments)
  - [ ] Run command in pre-merge mode
  - [ ] Verify all 10 comments detected
  - [ ] Verify severity categorization (SECURITY, CRITICAL)
  - [ ] Verify file:line references

- [ ] Test with no PR (local development)
  - [ ] Create branch without PR
  - [ ] Run command in local mode (should work)
  - [ ] Run command in pre-merge mode (should handle gracefully)
  - [ ] Verify clear message about no PR

- [ ] Test all three modes
  - [ ] Local mode: Verify fast, limited checks
  - [ ] Pre-PR mode: Verify comprehensive validations
  - [ ] Pre-merge mode: Verify PR analysis included
  - [ ] Compare execution times between modes

- [ ] Test with OpenSpec changes
  - [ ] Create branch with OpenSpec proposal
  - [ ] Run command
  - [ ] Verify OpenSpec validation runs
  - [ ] Test with valid and invalid proposals

- [ ] Performance validation
  - [ ] Local mode: Complete in < 2 minutes
  - [ ] Pre-PR mode: Complete in < 5 minutes
  - [ ] Pre-merge mode: Complete in < 10 minutes
  - [ ] Optimize slow checks if needed

- [ ] Cross-platform testing
  - [ ] Test on Windows (PowerShell and Git Bash)
  - [ ] Test on macOS
  - [ ] Test on Linux
  - [ ] Verify color output works on all platforms

## Phase 11: Current PR Resolution (PR #17)

**Note**: These tasks address the specific issues in the current PR to get it ready for merge.

- [ ] Resolve merge conflicts with main
  - [ ] Run `git fetch origin main`
  - [ ] Run `git merge origin/main`
  - [ ] Resolve conflicts in affected files
  - [ ] Commit merged changes

- [ ] Address CRITICAL Copilot comments
  - [ ] Fix syntax error in main.tf:299 (missing closing brace)
  - [ ] Fix security issue in user_data.sh:49 (quote $DOMAIN_NAME variable)
  - [ ] Fix critical bug in main.tf:256 (empty DOMAIN_NAME for CloudFlare)

- [ ] Address remaining Copilot comments
  - [ ] Remove duplicate line in README.md:241
  - [ ] Clarify DNS zone trailing dot in main.tf:307
  - [ ] Document parent zone lookup in main.tf:298
  - [ ] Add VPC ID to security group in alb.tf:37
  - [ ] Update CloudFlare description in spec.md:108
  - [ ] Fix SSL provider list in DEPLOYMENT_CHECKLIST.md:126
  - [ ] Fix hardcoded path in validate-all-configs.ps1:4

- [ ] Run pre-merge-check command
  - [ ] Execute `/pre-merge-check pre-merge` on PR #17
  - [ ] Verify "Ready to Merge" verdict
  - [ ] Confirm all issues resolved
  - [ ] Merge PR #17

## Dependencies

**Prerequisites before starting:**
- [x] .claude/ directory exists with commands
- [x] /validate-terraform command exists
- [x] /validate-yaml command exists
- [x] /validate-bash command exists
- [x] gh CLI installed and authenticated
- [x] openspec CLI installed
- [ ] .claude/ removed from .gitignore
- [ ] .claude/ committed to repository

**External dependencies:**
- git CLI - Already available
- gh CLI - Already installed for /review-pr
- openspec CLI - Already installed for OpenSpec workflow

## Validation Criteria

**For Phase 1 (Repository Preparation):**
- [ ] .claude/ not in .gitignore
- [ ] .claude/commands/ files tracked by git
- [ ] .claude/settings.local.json gitignored
- [ ] .claude/ visible in GitHub repository

**For Phase 2-6 (Command Implementation):**
- [ ] Command file exists at .claude/commands/pre-merge-check.md
- [ ] All three modes work correctly
- [ ] Git status checks detect conflicts and divergence
- [ ] All validation commands orchestrated successfully
- [ ] PR analysis works via gh CLI
- [ ] OpenSpec validation integrated

**For Phase 7-8 (Reporting and Error Handling):**
- [ ] Clear "Ready/Not Ready" verdict
- [ ] File:line references clickable in VSCode
- [ ] Progress indicators show status
- [ ] All error scenarios handled gracefully
- [ ] Execution times meet targets

**For Phase 9 (Documentation):**
- [ ] Command usage documented
- [ ] Examples provided for all modes
- [ ] Troubleshooting guide complete
- [ ] README.md updated

**For Phase 10 (Testing):**
- [ ] All test scenarios pass
- [ ] Performance criteria met
- [ ] Cross-platform compatibility verified

**Overall success:**
- [ ] Command reduces failed merge attempts from 30% to <10%
- [ ] Developers report increased confidence in merge readiness
- [ ] Command used regularly before merging PRs
- [ ] .claude/ commands versioned and reviewed like code