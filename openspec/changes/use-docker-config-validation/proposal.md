# Use Docker Image for Config Validation

**Status:** Draft
**Created:** 2025-12-04
**Author:** Elizabeth

## Overview

Replace pip-based config validation in CI workflows with Docker-based validation using the allocator image specified in `config.yaml`. This ensures validation always uses the exact same schema version that will be deployed.

## Problem

Currently, CI workflows install `lablink-allocator-service` from PyPI to run config validation:

```yaml
uv add lablink-allocator-service
uv run lablink-validate-config config.yaml --verbose
```

This creates a **version mismatch problem**:
- During active development, the allocator Docker image contains schema changes not yet published to PyPI
- CI validation uses the old schema from PyPI
- Deployment uses the new schema from Docker
- Result: Config fails validation in CI but would work fine in actual deployment

**Example scenario:**
- User updates `config.yaml` to use new DNS schema (direct domain specification)
- User sets `allocator.image_tag` to bleeding-edge commit (e.g., `linux-amd64-0d73aef...`)
- CI workflow installs old `lablink-allocator-service` from PyPI (has old schema)
- Validation fails because PyPI validator expects old pattern-based schema
- Deployment would work fine because Docker image has new schema

## Solution

Extract `allocator.image_tag` from `config.yaml` and use that Docker image for validation:

```yaml
IMAGE_TAG=$(grep -A5 "^allocator:" config.yaml | grep "image_tag:" | awk '{print $2}' | tr -d '"')
docker pull ghcr.io/talmolab/lablink-allocator-image:${IMAGE_TAG}
docker run --rm -v "$(pwd)/config.yaml:/config/config.yaml:ro" \
  ghcr.io/talmolab/lablink-allocator-image:${IMAGE_TAG} \
  lablink-validate-config /config/config.yaml --verbose
```

**Benefits:**
- ✅ Validation uses exact same schema version as deployment
- ✅ No version mismatch between validator and deployed service
- ✅ Works during active development (bleeding-edge commits)
- ✅ Works in production (stable version tags)
- ✅ Simple implementation (Docker available on GitHub runners)
- ✅ Permanent solution (not a temporary workaround)

## Scope

### In Scope
- Update `.github/workflows/terraform-deploy.yml` validation step
- Update `.github/workflows/config-validation.yml` validation step
- Add Docker login step for GitHub Container Registry
- Update validation failure messages with Docker instructions

### Out of Scope
- Changes to allocator service itself
- Changes to config.yaml schema
- Changes to Terraform infrastructure

## Breaking Changes

None. This is a CI/CD workflow improvement that doesn't affect:
- User-facing behavior
- Configuration schema
- Deployment process
- Infrastructure resources

## Dependencies

**External:**
- Docker (pre-installed on GitHub `ubuntu-latest` runners)
- GitHub Container Registry access via `GITHUB_TOKEN`
- Allocator Docker images at `ghcr.io/talmolab/lablink-allocator-image`

**Internal:**
- Assumes `allocator.image_tag` exists in `config.yaml`
- Assumes allocator image contains `lablink-validate-config` CLI tool

## Migration Path

No migration needed. This is a transparent CI workflow improvement. Users will not notice any difference except:
- Validation errors will match deployment reality
- Config validation may pass where it previously failed (if using new schema with old PyPI package)

## Alternatives Considered

### Alternative 1: Install from Git commit
Extract commit hash from image tag and install via:
```bash
uv pip install git+https://github.com/talmolab/lablink.git@${COMMIT}#subdirectory=packages/allocator
```

**Rejected because:**
- Assumes specific image tag format (brittle)
- More complex than Docker approach
- Breaks if tag format changes to semantic versions

### Alternative 2: Skip validation temporarily
Add workflow input to skip validation during development.

**Rejected because:**
- Loses safety checks
- Bad practice
- Doesn't solve root cause

### Alternative 3: Conditional fallback (Docker for dev, pip for prod)
Try Docker first, fall back to pip for stable versions.

**Rejected because:**
- Unnecessary complexity
- Docker approach works universally
- No benefit over pure Docker approach

## Success Criteria

- [ ] CI validation uses allocator Docker image from config.yaml
- [ ] Validation passes for configs using new schema features
- [ ] Validation fails appropriately for invalid configs
- [ ] Docker pull works without authentication issues
- [ ] Workflow execution time doesn't increase significantly
- [ ] All existing workflows continue to pass

## Open Questions

None.