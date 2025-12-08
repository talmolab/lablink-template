# Implementation Tasks

## Task List

### Phase 1: Rate Limit Documentation

- [x] Create docs/TESTING_BEST_PRACTICES.md
  - [x] Write comprehensive testing strategies guide
  - [x] Include rate limit decision matrix
  - [x] Document monitoring via crt.sh
  - [x] Add CI/CD testing considerations
  - [x] Provide troubleshooting steps for hitting limits

- [x] Update README.md
  - [x] Add "Let's Encrypt Rate Limits" section after DNS/SSL configuration
  - [x] Include quick reference table for testing strategies
  - [x] Link to TESTING_BEST_PRACTICES.md
  - [x] Add rate limit warnings with specific numbers

- [x] Update lablink-infrastructure/README.md
  - [x] Add rate limit details to SSL configuration section
  - [x] Include crt.sh monitoring link
  - [x] Document testing recommendations (IP-only, subdomain rotation, CloudFlare)
  - [x] Update SSL providers comparison

- [x] Update DEPLOYMENT_CHECKLIST.md
  - [x] Add rate limit awareness checklist items after SSL section
  - [x] Link to crt.sh monitoring
  - [x] Add testing strategy selection guidance
  - [x] Include certificate quota calculation steps

- [x] Update MANUAL_CLEANUP_GUIDE.md
  - [x] Add "Rate Limit Cleanup" section
  - [x] Note that deleting certificates doesn't help
  - [x] Provide subdomain rotation strategy
  - [x] Link to TESTING_BEST_PRACTICES.md

### Phase 2: Config Documentation

- [x] Create lablink-infrastructure/config/README.md
  - [x] Write overview of configuration system
  - [x] Create comparison table of all example configs
  - [x] Add decision tree for config selection
  - [x] Document rate limit considerations per config type
  - [x] Link to validation and testing docs

- [x] Standardize all *.example.yaml headers
  - [x] Update letsencrypt.example.yaml (add rate limit warnings)
  - [x] Update letsencrypt-manual.example.yaml (add rate limit warnings)
  - [x] Update ci-test.example.yaml (add team coordination notes)
  - [x] Update cloudflare.example.yaml (note: no rate limits)
  - [x] Update ip-only.example.yaml (note: rate-limit-free testing)
  - [x] Update acm.example.yaml (note: no Let's Encrypt limits)
  - [x] Update dev.example.yaml (ensure consistency)
  - [x] Update test.example.yaml (ensure consistency)
  - [x] Update prod.example.yaml (ensure consistency)
  - [x] Ensure consistent header format across all files

- [x] Evaluate example.config.yaml
  - [x] Check if redundant with named examples
  - [x] Updated header to clarify it's a reference doc with link to specific examples

### Phase 3: File Cleanup

- [x] Archive/move DNS-SSL-SIMPLIFICATION-PLAN.md
  - [x] Moved to openspec/changes/implement-simplified-dns-ssl/design.md
  - [x] No references to update
  - [x] Deleted from repo root

- [x] Delete DNS-SSL-TEAM-SUMMARY.md
  - [x] Verified content covered in OpenSpec proposal
  - [x] Removed from repo root

- [x] Delete PR6-TESTING-PLAN.md
  - [x] Confirmed PR merged and testing complete
  - [x] Removed from repo root

### Phase 4: Validation and Testing

- [x] Create cross-platform validation scripts
  - [x] Create scripts/validate-all-configs.ps1 (Windows/PowerShell)
  - [x] Create scripts/validate-all-configs.sh (Linux/macOS/Bash)
  - [x] Both scripts validate all 10 example configs
  - [x] Both scripts provide clear pass/fail output
  - [x] Both scripts exit with appropriate codes (0=success, 1=failure)

- [x] Validate all example configs
  - [x] Ran validation scripts on all *.example.yaml files
  - [x] Fixed cloudflare.example.yaml validation error (dns.enabled must be true for SSL)
  - [x] All 10 configs pass validation

- [x] Review documentation links
  - [x] All internal links use relative paths and are valid
  - [x] External links (Let's Encrypt, crt.sh) verified and current
  - [x] No broken links found

- [x] Test documentation clarity
  - [x] Config selection decision tree provides clear guidance
  - [x] Testing strategies are actionable with specific steps
  - [x] Rate limit warnings are prominent with ⚠️ symbols and bold text

## Implementation Order

**Sequential dependencies:**
1. Create TESTING_BEST_PRACTICES.md first (referenced by other docs)
2. Create config/README.md before standardizing example headers (provides template)
3. Update main docs (README, lablink-infrastructure/README) before example configs
4. Cleanup files after new docs are in place

**Parallelizable work:**
- Phase 1 (rate limit docs) and Phase 2 (config docs) can be done concurrently
- Example config header updates can be done in parallel once template exists
- File cleanup can happen anytime after new docs reference new locations

## Validation Checkpoints

After each phase:
- ✅ All new docs are clear, accurate, and well-formatted
- ✅ All links work (internal and external)
- ✅ Code examples are tested and correct
- ✅ Markdown renders properly in GitHub
- ✅ No broken references to moved/deleted files

After Phase 4:
- ✅ All example configs pass validation
- ✅ Documentation structure is intuitive
- ✅ Users can easily find rate limit information
- ✅ Config selection process is clear
- ✅ No obsolete docs in repo root

## Dependencies

- None (all work is documentation only)

## Rollback Plan

If documentation changes cause confusion:
1. Revert commits affecting problematic docs
2. Restore moved/deleted files if needed
3. Fix issues and re-apply
4. All changes are git-tracked, easy to revert

Rollback is low-risk since:
- No code changes
- No infrastructure changes
- Easy to update documentation
- Files can be restored from git history

## Notes

- **Priority:** Rate limit documentation (Phase 1) is highest priority - prevents user lockouts
- **Config README:** Should become canonical reference for config selection
- **Example headers:** Consistency is key - use same format across all files
- **File cleanup:** Verify no external references before deleting