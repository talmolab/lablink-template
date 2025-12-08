# Document Let's Encrypt Rate Limits and Clean Up Configuration Documentation

**Status:** Draft
**Created:** 2025-12-05
**Author:** Elizabeth

## Overview

Add comprehensive documentation about Let's Encrypt rate limits to prevent users from getting locked out during testing, and reorganize configuration documentation for better clarity and maintainability.

## Problem

### Rate Limit Documentation Gap

During ci-test deployment testing, we discovered that:
- Let's Encrypt has strict rate limits: **5 certificates per exact domain every 7 days**
- Users can easily hit this limit during infrastructure testing/debugging
- Once hit, there's a **7-day lockout with no override**
- No documentation warns users about this critical limitation
- No guidance on testing strategies to avoid rate limits

**Example scenario:**
- User deploys ci-test environment with Let's Encrypt
- Makes infrastructure changes and redeploys 5 times for debugging
- Gets rate limited and cannot deploy for 7 days
- No alternative testing strategy documented

### Documentation Organization Issues

Current state:
- **Scattered planning docs in repo root:** `DNS-SSL-SIMPLIFICATION-PLAN.md`, `DNS-SSL-TEAM-SUMMARY.md`, `PR6-TESTING-PLAN.md` - these are stale/completed planning docs
- **No config folder README:** Users must read example headers to understand differences
- **Duplicate/outdated config examples:** `example.config.yaml` vs named examples
- **Inconsistent example headers:** Some have warnings, some don't
- **No centralized testing best practices**
- **MANUAL_CLEANUP_GUIDE.md and DEPLOYMENT_CHECKLIST.md need updating** with rate limit info

This makes it hard for users to:
- Choose the right configuration for their use case
- Understand rate limit implications
- Find testing guidance
- Know which docs are current vs archived

## Solution

### 1. Add Rate Limit Documentation

Create comprehensive documentation covering:

**In README.md:**
- Let's Encrypt rate limits summary (5/domain/week, 50/registered-domain/week)
- Link to new testing best practices guide
- Quick reference table for testing strategies

**In lablink-infrastructure/README.md:**
- Rate limit details in SSL configuration section
- Link to crt.sh for monitoring certificate usage
- Testing recommendations (IP-only, subdomain rotation, CloudFlare)

**New file: docs/TESTING_BEST_PRACTICES.md:**
- Comprehensive testing guide with rate limit strategies
- Decision matrix: which strategy for which scenario
- Monitoring certificate usage via crt.sh
- What to do if you hit rate limits
- CI/CD considerations for ci-test environment

**In example configs:**
- Add rate limit warnings to `letsencrypt.example.yaml`
- Update `ci-test.example.yaml` with team coordination notes
- Ensure all examples have clear, consistent headers

**Update DEPLOYMENT_CHECKLIST.md:**
- Add rate limit awareness checklist items
- Link to monitoring tools (crt.sh)
- Testing strategy selection

**Update MANUAL_CLEANUP_GUIDE.md:**
- Add section on cleaning up after hitting rate limits
- Note that deleting certificates doesn't help (limit is on issuance)
- Guidance on switching to different subdomains

### 2. Clean Up Documentation Structure

**Delete obsolete files from repo root:**
- `DNS-SSL-SIMPLIFICATION-PLAN.md` → Move to `openspec/changes/implement-simplified-dns-ssl/design.md` or `docs/`
- `DNS-SSL-TEAM-SUMMARY.md` → Delete (covered by OpenSpec proposal in implement-simplified-dns-ssl)
- `PR6-TESTING-PLAN.md` → Delete (PR merged, testing complete, no longer relevant)

**Create lablink-infrastructure/config/README.md:**
- Overview of configuration system
- Table comparing all config examples with use cases
- Decision tree: which config to use when
- Rate limit considerations for each config type
- Link to validation and testing docs

**Keep and update essential root files:**
- `README.md` - Main entry point (add rate limits)
- `DEPLOYMENT_CHECKLIST.md` - Deployment workflow (add rate limit checks)
- `MANUAL_CLEANUP_GUIDE.md` - Cleanup procedures (add rate limit section)
- `AGENTS.md` / `CLAUDE.md` - AI assistant instructions

### 3. Standardize Example Configs

Ensure all `*.example.yaml` files have:
- Consistent header format with:
  - Use case description
  - Prerequisites
  - Rate limit warnings (for Let's Encrypt configs)
  - Setup instructions
  - Access URL
- Validation against schema
- Best practice configurations

Remove or consolidate:
- `example.config.yaml` - Check if redundant with named examples, delete if so

## Scope

### In Scope

**Documentation Files to Create:**
- **NEW:** docs/TESTING_BEST_PRACTICES.md (comprehensive testing guide)
- **NEW:** lablink-infrastructure/config/README.md (config comparison guide)

**Documentation Files to Update:**
- README.md (add rate limits section)
- lablink-infrastructure/README.md (update SSL section)
- DEPLOYMENT_CHECKLIST.md (add rate limit checks)
- MANUAL_CLEANUP_GUIDE.md (add rate limit cleanup section)
- All `*.example.yaml` headers (standardize and add warnings)

**File Cleanup:**
- Delete 3 obsolete markdown files from root:
  - `DNS-SSL-SIMPLIFICATION-PLAN.md` (move to appropriate location first)
  - `DNS-SSL-TEAM-SUMMARY.md`
  - `PR6-TESTING-PLAN.md`
- Evaluate and potentially delete `example.config.yaml` if redundant

**Config Validation:**
- Verify all example configs pass `lablink-validate-config`
- Ensure configurations follow documented best practices

### Out of Scope

- Implementing Let's Encrypt staging environment support (tracked separately)
- Adding certificate caching functionality
- Modifying Terraform infrastructure code
- Changes to allocator service validation logic
- Adding automated rate limit checking to workflows

## Breaking Changes

None. This is purely additive documentation and file reorganization. No behavior changes.

## Dependencies

**External:**
- Let's Encrypt rate limit documentation (for accurate references)
- Certificate Transparency Log (crt.sh) for monitoring examples

**Internal:**
- Requires understanding of existing config examples
- Should validate all examples still work after header updates

## Migration Path

No migration needed. This improves documentation for both new and existing users.

**User impact:**
- New users: Better guidance prevents rate limit issues
- Existing users: Can reference new docs for testing strategies
- Template maintainers: Cleaner repo structure, easier to maintain

## Alternatives Considered

### Alternative 1: Minimal documentation (just add warnings)

Add warnings to Let's Encrypt configs only, skip comprehensive testing guide.

**Rejected because:**
- Doesn't help users understand *how* to avoid rate limits
- No guidance on what to do when limits are hit
- Misses opportunity to improve overall documentation structure

### Alternative 2: Move all docs to dedicated docs/ folder

Move README.md, DEPLOYMENT_CHECKLIST.md, etc. to docs/.

**Rejected because:**
- README.md should stay at root (GitHub convention)
- DEPLOYMENT_CHECKLIST.md is frequently accessed, root is better
- Too disruptive for minimal benefit
- Current structure works for essential docs

### Alternative 3: Create separate rate-limits.md instead of TESTING_BEST_PRACTICES.md

Focused doc just on rate limits.

**Rejected because:**
- Testing strategies go beyond just rate limits
- Users need holistic testing guidance
- Better to consolidate testing knowledge in one place

## Success Criteria

- [ ] All documentation accurately describes Let's Encrypt rate limits with references
- [ ] Users can find clear testing strategies to avoid rate limits
- [ ] Config folder has README explaining all example files
- [ ] Obsolete planning docs removed from repo root
- [ ] All example configs have consistent, informative headers
- [ ] All example configs pass validation
- [ ] Documentation structure is clearer and easier to navigate
- [ ] ci-test team coordination is documented
- [ ] DEPLOYMENT_CHECKLIST.md includes rate limit checks
- [ ] MANUAL_CLEANUP_GUIDE.md includes rate limit guidance

## Open Questions

None. All details specified based on research and testing experience.

## References

- [Let's Encrypt Rate Limits (Official)](https://letsencrypt.org/docs/rate-limits/)
- [Let's Encrypt Staging Environment](https://letsencrypt.org/docs/staging-environment/)
- [Certificate Transparency Log (crt.sh)](https://crt.sh/)
- Current cert count for ci-test: https://crt.sh/?q=lablink-template-testing.com