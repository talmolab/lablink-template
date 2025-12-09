# Add Pre-Merge Validation Command

**Status:** Draft
**Created:** 2025-12-08
**Author:** Elizabeth

## Overview

Create a comprehensive pre-merge validation command that orchestrates all code quality checks, git status validation, PR analysis, and provides a clear merge readiness verdict before merging pull requests.

## Problem

### Current Manual Pre-Merge Process

Developers currently must manually execute multiple steps before merging a PR:

1. Run `/validate-terraform` manually
2. Run `/validate-yaml` manually
3. Run `/validate-bash` manually
4. Check `git status` for conflicts
5. Manually review GitHub Copilot comments on PR
6. Manually check CI status
7. Manually verify PR approval status
8. Guess whether PR is truly ready to merge

**Problems this creates:**

- **Missed validation steps**: Easy to forget one of 5+ manual checks
- **Merge conflicts discovered late**: Git conflicts only found when attempting merge
- **Unaddressed review comments**: Copilot suggestions overlooked or forgotten
- **Failed merges**: Preventable failures that waste time and CI resources
- **Low confidence**: Developers unsure if PR is actually ready
- **Inconsistent process**: Different developers check different things

### Real Example: Current PR #17

The current PR (elizabeth/add-config-validation-ci) has:

- ✅ Syntax validation passed (automated)
- ⚠️ **Merge conflicts** with main (undetected until now)
- ⚠️ **10 unaddressed Copilot comments** including:
  - **CRITICAL**: Syntax error in main.tf:299 (missing closing brace)
  - **SECURITY**: Unquoted variable in user_data.sh:49 (injection risk)
  - **BUG**: Empty DOMAIN_NAME in main.tf:256 (breaks CloudFlare configs)
  - 7 other issues (duplicate lines, missing fields, inconsistencies)
- ⚠️ No CI status checks running
- ⚠️ `.claude` directory not tracked (commands not versioned)

Without a comprehensive pre-merge check, these issues would be discovered during or after merge, requiring cleanup and rework.

### .claude Directory Not Tracked

Currently `.claude/` is gitignored (line 233 in .gitignore), which means:

- Claude commands are not versioned in git
- Developers may have different command availability
- Command updates don't go through PR review process
- No history of command changes
- New developers don't get commands automatically

This is inconsistent with treating commands as code that should be reviewed and versioned.

## Solution

### Create /pre-merge-check Command

Create `.claude/commands/pre-merge-check.md` that orchestrates existing validation commands and adds PR-specific checks.

#### Execution Modes

**Mode 1: local** (Fast, subset of checks)
- Git status validation
- Formatting checks only
- **Time**: 1-2 minutes
- **Use**: Before pushing changes

**Mode 2: pre-pr** (Comprehensive validation)
- All Mode 1 checks
- Full validation suite (Terraform, YAML, Bash)
- Branch status vs main
- **Time**: 3-5 minutes
- **Use**: Before creating PR

**Mode 3: pre-merge** (Ultra-comprehensive with PR analysis)
- All Mode 2 checks
- PR approval status
- CI status checks
- Review comment analysis
- Copilot comment detection
- **Time**: 5-10 minutes
- **Use**: Right before merging PR

#### Check Categories

**Category A: Git Status** (All modes)
1. Check for uncommitted changes
2. Detect merge conflicts with target branch
3. Check branch divergence from main
4. Verify working tree is clean

**Category B: Code Quality** (Pre-PR and Pre-Merge modes)
1. Execute `/validate-terraform` (reuse existing command)
2. Execute `/validate-yaml` (reuse existing command)
3. Execute `/validate-bash` (reuse existing command)
4. Aggregate validation results

**Category C: PR Validation** (Pre-Merge mode only)
1. Fetch PR metadata via `gh pr view`
2. Check approval status
3. Check CI status (all checks passing)
4. Fetch review comments via `gh api`
5. Identify GitHub Copilot comments
6. Check if comments are resolved or addressed
7. Report unaddressed comments with file:line references

**Category D: OpenSpec Validation** (Conditional)
1. Detect OpenSpec changes in PR
2. Run `openspec validate --strict` if changes found
3. Check for breaking changes without proposals
4. Report OpenSpec validation results

#### Verdict and Reporting

The command provides a clear verdict:

**✅ READY TO MERGE**
```
All checks passed:
  ✅ No merge conflicts
  ✅ All validations passed (Terraform, YAML, Bash)
  ✅ PR approved
  ✅ CI checks passing
  ✅ All review comments addressed

You can safely merge this PR.
```

**⛔ NOT READY TO MERGE**
```
Blocking issues found:

1. Merge Conflicts (2 files)
   - lablink-infrastructure/main.tf
   - README.md
   Action: Merge origin/main and resolve conflicts

2. Validation Failures (1)
   - Terraform: Syntax error in main.tf:299 (missing closing brace)
   Action: Fix syntax error

3. Unaddressed Review Comments (10)
   - [SECURITY] user_data.sh:49 - Unquoted variable injection risk
   - [CRITICAL] main.tf:256 - Empty DOMAIN_NAME breaks CloudFlare
   - README.md:241 - Remove duplicate rate limit line
   ... (7 more)
   Action: Address all Copilot comments

Do not merge until all issues are resolved.
```

### Track .claude Directory in Git

**Change .gitignore:**
- Remove line 233: `.claude/`
- Add line to ignore only local settings: `.claude/settings.local.json`

**Commit .claude directory:**
- Add all `.claude/commands/` files
- Include README documentation
- Version commands like code

**Benefits:**
- Commands are versioned and reviewed
- All developers have consistent command availability
- Command changes go through PR process
- History of command evolution
- New developers get commands automatically

## Scope

### In Scope

**New Command:**
- `.claude/commands/pre-merge-check.md` - Orchestration command with three modes

**Implementation:**
- Git status validation logic
- Merge conflict detection
- Validation orchestration (reuse existing commands)
- PR analysis via gh CLI
- Review comment fetching and filtering
- Copilot comment identification
- OpenSpec validation integration
- Clear verdict and reporting logic

**Repository Changes:**
- Remove `.claude/` from `.gitignore`
- Add `.claude/settings.local.json` to `.gitignore` (for personal settings)
- Commit `.claude/` directory with all commands

**Documentation:**
- Command usage documentation in `.claude/commands/pre-merge-check.md`
- Examples for each mode
- Troubleshooting guide
- Update README.md to mention command
- Update `.claude/commands/README.md`

### Out of Scope

**Not Included:**
- Auto-fixing issues (command only reports, doesn't fix)
- Modifying existing validation commands
- Creating new validation logic (orchestrate existing)
- CI integration (command is for local use)
- Automated merging
- GitHub App or bot integration
- Custom status check creation

**Deferred to Future:**
- Caching validation results for unchanged files
- Parallel execution of validation commands
- Custom check plugins
- Auto-fix mode with --fix flag

## Breaking Changes

None. This is purely additive functionality.

**Tracking .claude directory:**
- Not a breaking change - improves versioning
- Existing workflows unaffected
- Commands already exist, just now tracked

## Dependencies

### Existing Infrastructure (Reused)

**Commands:**
- `/validate-terraform` - Terraform validation
- `/validate-yaml` - YAML config validation
- `/validate-bash` - Bash script validation

**Tools:**
- `git` - Already available everywhere
- `gh` CLI - Already used in `/review-pr` command
- `openspec` - Already installed for OpenSpec workflow

**No new dependencies required.**

### External Dependencies

- GitHub API (via gh CLI) - Already in use
- Git repository context - Already available
- OpenSpec CLI - Already installed

## Migration Path

No migration needed. This is purely additive.

**Rollout Plan:**

1. **Create OpenSpec proposal** (this document)
2. **Remove .claude from .gitignore**
3. **Commit .claude directory**
4. **Implement command** following tasks.md
5. **Test with current PR** (PR #17)
6. **Document usage** and examples
7. **Announce to team**

**Rollback:**
- Command is optional, can be removed without impact
- Existing validation commands still work independently
- No impact on CI workflows
- Can re-add .claude to .gitignore if tracking causes issues (unlikely)

## Alternatives Considered

### Alternative 1: Makefile with make pre-merge target

Create `Makefile` with `make pre-merge` target that runs all checks.

**Rejected because:**
- Less discoverable than Claude command
- No integration with Claude workflow
- Requires make installed
- Can't provide intelligent assistance
- Harder to provide contextual help

### Alternative 2: GitHub Actions workflow

Create workflow that runs comprehensive checks on every PR.

**Rejected because:**
- Doesn't help local development (slower feedback)
- Can't detect merge conflicts or git status issues
- Can't provide interactive guidance
- Complementary but not a substitute for local command

### Alternative 3: Pre-commit git hook

Install git pre-commit hook that runs validations before each commit.

**Rejected because:**
- Too intrusive (slows down every commit)
- Can be disabled/bypassed easily
- Wrong granularity (commit vs PR)
- Doesn't handle PR-specific checks (approval, comments, CI)

### Alternative 4: Shell script in scripts/

Create `scripts/pre-merge-check.sh` shell script.

**Rejected because:**
- Not integrated with Claude Code
- Harder to discover
- No Claude-powered assistance
- Maintenance separate from commands
- Less consistent with existing workflow

### Alternative 5: Document manual checklist only

Keep manual process but create comprehensive checklist in documentation.

**Rejected because:**
- Doesn't solve the problem (still manual)
- Error-prone (humans skip steps)
- Not repeatable (different people check differently)
- No enforcement
- Doesn't provide quick feedback

## Success Criteria

**Functional:**
- [ ] Command completes in < 10 minutes for full check (pre-merge mode)
- [ ] Command completes in < 2 minutes for fast check (local mode)
- [ ] Detects 100% of merge conflicts
- [ ] Reports all validation failures from existing commands
- [ ] Fetches and displays PR review comments
- [ ] Identifies Copilot comments correctly
- [ ] Provides clear Ready/Not Ready verdict
- [ ] Works in all three modes (local, pre-pr, pre-merge)

**Non-Functional:**
- [ ] Clear, readable output format with colors/formatting
- [ ] Actionable error messages with suggested fixes
- [ ] Progress indicators for long-running operations
- [ ] Graceful failure handling (network, gh CLI missing, etc.)
- [ ] Comprehensive documentation with examples

**Repository:**
- [ ] .claude directory tracked in git
- [ ] .claude/settings.local.json gitignored for personal settings
- [ ] Commands versioned and reviewed like code
- [ ] All developers have consistent command availability

**Integration:**
- [ ] Orchestrates existing /validate-* commands correctly
- [ ] Compatible with gh CLI for PR analysis
- [ ] Works with OpenSpec workflow
- [ ] Doesn't interfere with CI workflows

## Open Questions

None. Implementation details are clear based on planning analysis.

## References

- [Existing validation commands](../../../.claude/commands/) - To be orchestrated
- [gh CLI documentation](https://cli.github.com/manual/) - PR analysis tool
- [OpenSpec validation](https://github.com/openspec-framework/openspec) - Spec validation
- Planning analysis above provides comprehensive design details