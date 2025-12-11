# Documentation Capability

## ADDED Requirements

### Requirement: Rate Limit Documentation
The template SHALL provide comprehensive documentation about Let's Encrypt rate limits to prevent users from being locked out during testing.

**Rationale:** Let's Encrypt has strict rate limits (5 certificates per exact domain every 7 days) that users easily hit during testing, resulting in 7-day lockouts with no override. Without documentation, users discover this the hard way.

#### Scenario: User reads rate limits before deploying with Let's Encrypt
**Given** a user wants to deploy with Let's Encrypt SSL
**When** they read the README.md or lablink-infrastructure/README.md
**Then** they MUST see clear warnings about rate limits including:
- Specific limit numbers (5 per domain per week, 50 per registered domain per week)
- Consequences of hitting limits (7-day lockout, no override)
- Link to testing strategies document

#### Scenario: User finds testing strategies to avoid rate limits
**Given** a user wants to test infrastructure changes frequently
**When** they read docs/TESTING_BEST_PRACTICES.md
**Then** they MUST find documented strategies including:
- IP-only deployment (no rate limits)
- Subdomain rotation (5 attempts per subdomain)
- CloudFlare SSL (no Let's Encrypt limits)
- When to use each strategy

#### Scenario: User monitors certificate usage
**Given** a user has deployed with Let's Encrypt
**When** they want to check how many certificates remain
**Then** documentation MUST provide:
- Link to crt.sh for their domain
- Instructions to calculate remaining quota
- Warning indicators (e.g., 3/5 certificates used)

#### Scenario: User hits rate limit and needs guidance
**Given** a user has hit the 5 certificates per week limit
**When** they consult TESTING_BEST_PRACTICES.md or MANUAL_CLEANUP_GUIDE.md
**Then** they MUST find guidance on:
- Why deleting certificates doesn't help (limit is on issuance)
- Switching to a different subdomain
- Using IP-only deployment for testing
- Estimated time until rate limit resets

### Requirement: Configuration Documentation
The template SHALL provide clear documentation explaining all configuration options and helping users select the right configuration for their use case.

**Rationale:** The template has 9 different example configs with different purposes, but no centralized guide explaining when to use which one. Users must read all example headers to understand differences.

#### Scenario: User selects appropriate configuration
**Given** a user wants to deploy LabLink
**When** they read lablink-infrastructure/config/README.md
**Then** they MUST find:
- Comparison table of all example configs
- Use case for each config (development, staging, production, testing)
- Prerequisites for each config
- Rate limit implications for each config
- Decision tree or flowchart for config selection

#### Scenario: User understands config file header
**Given** a user opens any *.example.yaml file
**When** they read the header comments
**Then** the header MUST include:
- Use case description (what this config is for)
- Prerequisites (Route53 zone, CloudFlare account, etc.)
- Rate limit warnings (if using Let's Encrypt)
- Setup instructions (step-by-step)
- Expected access URL after deployment

#### Scenario: User compares Let's Encrypt vs CloudFlare vs IP-only
**Given** a user is deciding between SSL providers
**When** they consult lablink-infrastructure/config/README.md
**Then** they MUST see comparison including:
- Rate limits (Let's Encrypt: 5/week, CloudFlare: none, IP-only: n/a)
- Setup complexity (Let's Encrypt: medium, CloudFlare: high, IP-only: low)
- Security (HTTPS vs HTTP)
- Use cases (production vs testing)

### Requirement: Deployment Checklist Updates
The deployment checklist SHALL include rate limit awareness checks to prevent accidental lockouts.

**Rationale:** Users follow DEPLOYMENT_CHECKLIST.md during deployment but currently get no warning about rate limits, leading to preventable lockouts.

#### Scenario: User checks rate limit status before deploying
**Given** a user is following DEPLOYMENT_CHECKLIST.md
**When** they reach the SSL configuration section
**Then** the checklist MUST include items for:
- Understanding rate limits if using Let's Encrypt
- Checking existing certificate count via crt.sh
- Considering alternative testing strategies for frequent deployments
- Link to TESTING_BEST_PRACTICES.md

### Requirement: Manual Cleanup Guide Updates
The manual cleanup guide SHALL include guidance on dealing with rate limit situations.

**Rationale:** Users who hit rate limits often try to "clean up" certificates thinking it will help, but deletion doesn't reset the issuance limit.

#### Scenario: User tries to recover from rate limit
**Given** a user has hit the Let's Encrypt rate limit
**When** they consult MANUAL_CLEANUP_GUIDE.md
**Then** they MUST find:
- Explanation that deleting certificates doesn't help
- Alternative: switch to different subdomain
- Alternative: use IP-only deployment
- Expected wait time (7 days from oldest cert in window)

## MODIFIED Requirements

### Requirement: Repository Documentation Structure
The repository SHALL maintain a clean, well-organized documentation structure with obsolete files removed.

**Rationale:** Stale planning documents in the repo root confuse users about which docs are current and authoritative.

**Old Behavior:**
- Planning documents (`DNS-SSL-SIMPLIFICATION-PLAN.md`, `DNS-SSL-TEAM-SUMMARY.md`, `PR6-TESTING-PLAN.md`) in repo root
- No config folder README
- Inconsistent example config headers

**New Behavior:**
- Planning documents moved to appropriate locations or deleted
- Config folder has comprehensive README
- All example configs have standardized headers

#### Scenario: User navigates repository documentation
**Given** a new user browses the repository
**When** they look at the root directory
**Then** they MUST see only current, essential documentation:
- README.md (main entry point)
- DEPLOYMENT_CHECKLIST.md (deployment workflow)
- MANUAL_CLEANUP_GUIDE.md (cleanup procedures)
- AGENTS.md / CLAUDE.md (AI assistant instructions)

**And** they MUST NOT see:
- Completed planning documents
- Obsolete testing plans
- Duplicat configuration examples without clear purpose

#### Scenario: User finds archived planning documents
**Given** a user wants to understand past architectural decisions
**When** they search for planning documents
**Then** they MUST find them in appropriate locations:
- OpenSpec changes directory (`openspec/changes/*/design.md`)
- OR docs/ directory with clear archive designation

### Requirement: Example Configuration Consistency
All example configuration files SHALL have consistent, informative headers following a standard format.

**Rationale:** Current example configs have inconsistent headers, making it hard to quickly understand differences between configs.

**Old Behavior:**
- Some configs have detailed headers, some minimal
- Rate limit warnings missing from Let's Encrypt configs
- Inconsistent structure (some have setup steps, some don't)

**New Behavior:**
- All configs follow standard header template
- Let's Encrypt configs include rate limit warnings
- All configs include setup instructions and expected outcomes

#### Scenario: User compares two example configs
**Given** a user opens two different *.example.yaml files
**When** they read the headers
**Then** both headers MUST follow the same structure:
- Use case description (first line comment)
- Prerequisites section
- Important warnings (if applicable)
- Setup instructions section
- Expected access URL

### Requirement: Configuration Validation Tooling
The template SHALL provide cross-platform scripts to validate all example configurations, ensuring they remain valid as the schema evolves.

**Rationale:** With 10 different example configurations, manual validation is error-prone. Automated validation scripts ensure all examples remain valid and catch configuration errors before users encounter them.

#### Scenario: Maintainer validates all configs on Windows
**Given** a template maintainer is on Windows
**When** they run scripts/validate-all-configs.ps1
**Then** the script MUST:
- Validate all 10 example configuration files
- Report pass/fail status for each config
- Show detailed error messages for failures
- Exit with code 0 on success, 1 on failure

#### Scenario: Maintainer validates all configs on Linux/macOS
**Given** a template maintainer is on Linux or macOS
**When** they run scripts/validate-all-configs.sh
**Then** the script MUST:
- Validate all 10 example configuration files
- Report pass/fail status for each config with color-coded output
- Show detailed error messages for failures
- Exit with code 0 on success, 1 on failure

#### Scenario: Validation catches config error
**Given** an example config has an invalid setting (e.g., ssl.provider="cloudflare" with dns.enabled=false)
**When** a maintainer runs the validation script
**Then** the script MUST:
- Detect the validation error
- Report which config file failed
- Display the specific validation error message
- Prevent the invalid config from being committed

## REMOVED Requirements

None. This change is purely additive documentation.

## References

- [Let's Encrypt Rate Limits](https://letsencrypt.org/docs/rate-limits/)
- [Let's Encrypt Staging Environment](https://letsencrypt.org/docs/staging-environment/)
- [Certificate Transparency Log](https://crt.sh/)