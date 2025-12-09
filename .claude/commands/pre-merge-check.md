# Pre-Merge Check Command

Comprehensive validation before merging pull requests. Orchestrates all validation steps, detects merge conflicts, analyzes PR status, and provides clear merge readiness verdict.

## Usage

```
Run pre-merge checks in [mode] mode
```

Where `[mode]` is one of:
- `local` - Fast checks (1-2 min): git status + formatting only
- `pre-pr` - Comprehensive (3-5 min): all validations before creating PR
- `pre-merge` - Ultra-comprehensive (5-10 min): includes PR analysis before merging
- If no mode specified, defaults to `pre-merge`

## What This Command Does

### All Modes: Git Status Validation
1. Check for uncommitted changes
2. Detect merge conflicts with main branch
3. Check branch divergence from main
4. Report git status issues

### Pre-PR and Pre-Merge Modes: Code Quality Validation
1. Execute `/validate-terraform` command
2. Execute `/validate-yaml` command
3. Execute `/validate-bash` command
4. Aggregate all validation results

### Pre-Merge Mode Only: PR Analysis
1. Fetch PR metadata via `gh pr view`
2. Check PR approval status
3. Check CI status checks
4. Fetch all review comments via `gh api`
5. Identify unaddressed GitHub Copilot comments
6. Check if OpenSpec changes need validation

### Final Verdict
- Display ✅ "READY TO MERGE" or ⛔ "NOT READY TO MERGE"
- List all blocking issues with file:line references
- Provide specific remediation steps
- Exit with appropriate status code (0=ready, 1=not ready)

## Examples

**Quick local check before pushing:**
```
Run pre-merge checks in local mode
```

**Before creating PR:**
```
Run pre-merge checks in pre-pr mode
```

**Before merging PR (full validation):**
```
Run pre-merge checks in pre-merge mode
```
or simply:
```
Run pre-merge checks
```

## Implementation Instructions

Execute the following comprehensive pre-merge validation workflow:

### Step 1: Parse Mode and Setup

1. Extract mode from user request (local, pre-pr, pre-merge, or default to pre-merge)
2. Validate mode is valid
3. Display header:
   ```
   🔍 Pre-Merge Validation (mode: [mode])
   ═══════════════════════════════════════
   ```

### Step 2: Git Status Validation (All Modes)

Display: `[1/N] Git Status Checks...`

1. **Check for uncommitted changes:**
   ```bash
   git status --porcelain
   ```
   - If output not empty: Report uncommitted files
   - Severity: WARNING (not blocking in local mode, blocking in pre-pr/pre-merge)

2. **Detect merge conflicts:**
   ```bash
   git fetch origin main
   git merge-base HEAD origin/main
   ```
   Then check for conflicts:
   ```bash
   git diff --name-only origin/main...HEAD
   ```
   Better approach - detect conflicts without modifying tree:
   ```bash
   # Check if merge would have conflicts
   git merge-tree $(git merge-base HEAD origin/main) HEAD origin/main | grep -q "^changed in both"
   ```
   - If conflicts detected: List conflicting files
   - Suggest: `git fetch origin main && git merge origin/main`
   - Severity: CRITICAL (blocks everything, exit early)

3. **Check branch divergence:**
   ```bash
   git rev-list --left-right --count HEAD...origin/main
   ```
   - Parse output for commits ahead/behind
   - Report if branch is behind or diverged
   - Severity: INFO

**If merge conflicts found, EXIT IMMEDIATELY with verdict "NOT READY TO MERGE"**

### Step 3: Code Quality Validation (Pre-PR and Pre-Merge Modes)

Display: `[2/N] Code Quality Validation...`

**For local mode:** Only run fast format check:
```bash
cd lablink-infrastructure && terraform fmt -check -recursive
```

**For pre-pr and pre-merge modes:** Run all validations:

1. **Terraform Validation:**
   - Execute the `/validate-terraform` command
   - Capture output and parse for errors
   - Store results (pass/fail, error details)

2. **YAML Validation:**
   - Execute the `/validate-yaml` command
   - Capture output and parse for errors
   - Store results (pass/fail, error details)

3. **Bash Validation:**
   - Execute the `/validate-bash` command
   - Capture output and parse for errors
   - Store results (pass/fail, error details)

4. **Aggregate Results:**
   - Count total failures across all validations
   - Collect all error messages with file:line references
   - Determine if validation passed (all 3 passed)

### Step 4: PR Analysis (Pre-Merge Mode Only)

Display: `[3/N] PR Analysis...`

1. **Check gh CLI availability:**
   ```bash
   which gh || where gh
   ```
   - If not found: Display warning, skip PR checks
   - If found but not authenticated: Show `gh auth status`

2. **Get current PR number:**
   ```bash
   gh pr view --json number --jq '.number'
   ```
   - If fails: No PR for this branch, skip PR checks with info message

3. **Fetch PR metadata:**
   ```bash
   gh pr view --json title,state,author,reviews,statusCheckRollup
   ```
   - Parse JSON output
   - Store PR title, state, author

4. **Check approval status:**
   - From PR metadata, extract reviews
   - Count approvals (reviews with state="APPROVED")
   - Report approval count and required approvals

5. **Check CI status:**
   - From statusCheckRollup, check each status check
   - Identify passing vs failing checks
   - Handle edge case: empty statusCheckRollup (no CI configured)
   - Report: "✅ CI Checks: 2/2 passing" or "❌ CI Checks: 1/2 failing"

6. **Fetch review comments:**
   ```bash
   gh api repos/:owner/:repo/pulls/:number/comments --paginate
   ```
   - Parse JSON for all comments
   - Extract: file, line, body, user.login, id

7. **Identify Copilot comments:**
   - Filter comments where `user.login` contains "copilot"
   - For each Copilot comment:
     - Check if resolved (has reply or marked resolved)
     - Extract severity from body (SECURITY, CRITICAL, etc.)
     - Store: file:line, severity, body excerpt

8. **Count unaddressed comments:**
   - Total unaddressed Copilot comments
   - Group by severity (SECURITY, CRITICAL, normal)

### Step 5: OpenSpec Validation (Conditional)

Display: `[4/N] OpenSpec Validation...` (if applicable)

1. **Detect OpenSpec changes:**
   ```bash
   git diff --name-only origin/main...HEAD | grep "^openspec/"
   ```
   - If no OpenSpec files changed: Skip this step

2. **Run OpenSpec validation:**
   ```bash
   openspec validate --strict
   ```
   - Capture output and exit code
   - Parse for validation errors

3. **Check for breaking changes:**
   - Look for "BREAKING" or "breaking changes" in proposals
   - Verify proposal exists if breaking changes present

### Step 6: Generate Final Report

Display: `[N/N] Generating Report...`

**Calculate verdict:**
- If merge conflicts: NOT READY
- If any validation failed: NOT READY
- If CI checks failing: NOT READY
- If SECURITY or CRITICAL Copilot comments unaddressed: NOT READY
- If OpenSpec validation failed: NOT READY
- Otherwise: READY TO MERGE

**Display verdict and details:**

#### If READY TO MERGE:
```
✅ READY TO MERGE
═══════════════════════════════════════

All checks passed:
  ✅ No merge conflicts
  ✅ Working tree clean
  ✅ Terraform validation passed
  ✅ YAML validation passed
  ✅ Bash validation passed
  ✅ PR approved by 2 reviewers
  ✅ CI checks passing (2/2)
  ✅ All review comments addressed (0 unaddressed)

Execution time: Xm Ys

🎉 You can safely merge this PR!
```

#### If NOT READY TO MERGE:
```
⛔ NOT READY TO MERGE
═══════════════════════════════════════

Blocking issues found:

1. MERGE CONFLICTS (2 files)
   Files in conflict:
     • lablink-infrastructure/main.tf
     • README.md

   Action Required:
     git fetch origin main
     git merge origin/main
     # Resolve conflicts in editor
     git add <resolved-files>
     git commit

2. VALIDATION FAILURES (1)
   ❌ Terraform:
     • main.tf:299 - Syntax error (missing closing brace)

   Action Required:
     Fix syntax error and run terraform validate

3. UNADDRESSED REVIEW COMMENTS (10)

   SECURITY (1):
     • user_data.sh:49 - Quote variable to prevent injection

   CRITICAL (1):
     • main.tf:256 - Empty DOMAIN_NAME breaks CloudFlare configs

   Suggestions (8):
     • README.md:241 - Remove duplicate rate limit line
     • main.tf:307 - Clarify DNS zone trailing dot handling
     • main.tf:298 - Document parent zone lookup edge case
     ... (5 more)

   Action Required:
     Address all Copilot comments or reply with rationale

4. CI CHECKS FAILING (1 of 2)
   ❌ Terraform Format - FAILED
   ✅ Config Validation - PASSED

   Action Required:
     Fix CI failures before merge

═══════════════════════════════════════
Do not merge until all issues are resolved.
Run /pre-merge-check again after fixes.
```

### Step 7: Exit with Status Code

- Exit 0 if READY TO MERGE
- Exit 1 if NOT READY TO MERGE

## Error Handling

**gh CLI not installed:**
- Display: "⚠️ gh CLI not found - skipping PR analysis"
- Suggest: "Install with: brew install gh (macOS) or see https://cli.github.com"
- Continue with other checks

**Not in git repository:**
- Display: "❌ Not in a git repository"
- Suggest: "Run this command from the repository root"
- Exit with status 1

**PR not found:**
- Display: "ℹ️ No PR found for this branch"
- Suggest: "Create a PR first, or skip pre-merge mode"
- Continue with other checks (not blocking)

**Network failures:**
- Display: "⚠️ Network error fetching PR data"
- Suggest: "Check internet connection and try again"
- Continue with other checks (not blocking)

**OpenSpec not installed:**
- Display: "⚠️ openspec not found - skipping OpenSpec validation"
- Continue with other checks (only blocking if OpenSpec files changed)

## Notes

- This command orchestrates existing validation commands - it doesn't duplicate logic
- Use TodoWrite to track progress through validation phases
- Show progress indicators for long-running operations
- Use colors if terminal supports (green=✅, red=❌, yellow=⚠️)
- Make file:line references clickable in VSCode format: `file.ext:123`
- Execution time targets: local <2min, pre-pr <5min, pre-merge <10min