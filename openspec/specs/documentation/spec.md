# Documentation Specification

## Purpose

This specification defines documentation requirements for rate limits, configuration guidance, and testing best practices.

## Requirements

### Requirement: Rate Limit Documentation
The template SHALL provide comprehensive documentation about Let's Encrypt rate limits to prevent users from being locked out during testing.

#### Scenario: User reads rate limits before deploying with Let's Encrypt
- **GIVEN** a user wants to deploy with Let's Encrypt SSL
- **WHEN** they read the README.md or lablink-infrastructure/README.md
- **THEN** they MUST see clear warnings about rate limits including:
  - Specific limit numbers (5 per domain per week, 50 per registered domain per week)
  - Consequences of hitting limits (7-day lockout, no override)
  - Link to testing strategies document

#### Scenario: User finds testing strategies to avoid rate limits
- **GIVEN** a user wants to test infrastructure changes frequently
- **WHEN** they read docs/TESTING_BEST_PRACTICES.md
- **THEN** they MUST find documented strategies including:
  - IP-only deployment (no rate limits)
  - Subdomain rotation (5 attempts per subdomain)
  - CloudFlare SSL (no Let's Encrypt limits)
  - When to use each strategy

#### Scenario: User hits rate limit and needs guidance
- **GIVEN** a user has hit the 5 certificates per week limit
- **WHEN** they consult TESTING_BEST_PRACTICES.md or MANUAL_CLEANUP_GUIDE.md
- **THEN** they MUST find guidance on:
  - Why deleting certificates doesn't help (limit is on issuance)
  - Switching to a different subdomain
  - Using IP-only deployment for testing
  - Estimated time until rate limit resets

### Requirement: Configuration Documentation
The template SHALL provide clear documentation explaining all configuration options and helping users select the right configuration for their use case.

#### Scenario: User selects appropriate configuration
- **GIVEN** a user wants to deploy LabLink
- **WHEN** they read lablink-infrastructure/config/README.md
- **THEN** they MUST find:
  - Comparison table of all example configs
  - Use case for each config (development, staging, production, testing)
  - Prerequisites for each config
  - Rate limit implications for each config

#### Scenario: User understands config file header
- **GIVEN** a user opens any *.example.yaml file
- **WHEN** they read the header comments
- **THEN** the header MUST include:
  - Use case description (what this config is for)
  - Prerequisites (Route53 zone, CloudFlare account, etc.)
  - Rate limit warnings (if using Let's Encrypt)
  - Setup instructions (step-by-step)
  - Expected access URL after deployment

#### Scenario: User compares Let's Encrypt vs CloudFlare vs IP-only
- **GIVEN** a user is deciding between SSL providers
- **WHEN** they consult lablink-infrastructure/config/README.md
- **THEN** they MUST see comparison including:
  - Rate limits (Let's Encrypt: 5/week, CloudFlare: none, IP-only: n/a)
  - Setup complexity (Let's Encrypt: medium, CloudFlare: high, IP-only: low)
  - Security (HTTPS vs HTTP)
  - Use cases (production vs testing)

### Requirement: Deployment Checklist Updates
The deployment checklist SHALL include rate limit awareness checks to prevent accidental lockouts.

#### Scenario: User reviews checklist before frequent testing
- **GIVEN** a user is about to perform multiple test deployments
- **WHEN** they consult DEPLOYMENT_CHECKLIST.md
- **THEN** they MUST see checklist items for:
  - Verify SSL provider choice (avoid Let's Encrypt for frequent testing)
  - Check current certificate usage via crt.sh
  - Plan subdomain rotation if using Let's Encrypt
  - Consider IP-only for infrastructure testing

### Requirement: Stale Documentation Cleanup
The template repository SHALL NOT contain outdated planning documents that could confuse users.

#### Scenario: User browses repository root
- **GIVEN** a user explores the repository
- **WHEN** they view files in the root directory
- **THEN** they MUST NOT see:
  - Completed planning documents (DNS-SSL-SIMPLIFICATION-PLAN.md, DNS-SSL-TEAM-SUMMARY.md, PR6-TESTING-PLAN.md)
  - Outdated implementation notes
  - Superseded design documents
- **AND** all completed planning work MUST be archived or removed