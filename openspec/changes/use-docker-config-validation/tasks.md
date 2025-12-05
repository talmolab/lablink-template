# Implementation Tasks

## Task List

- [x] Update terraform-deploy.yml workflow
  - [x] Remove UV setup step
  - [x] Add Docker login step for GHCR authentication
  - [x] Replace pip-based validation with Docker-based validation
  - [x] Extract `allocator.image_tag` from config.yaml
  - [x] Pull allocator Docker image
  - [x] Run validator using Docker image with volume mount

- [x] Update config-validation.yml workflow
  - [x] Remove UV setup step
  - [x] Remove temp project creation step
  - [x] Add Docker login step for GHCR authentication
  - [x] Replace pip-based validation with Docker-based validation
  - [x] Extract `allocator.image_tag` from config file path
  - [x] Pull allocator Docker image
  - [x] Run validator using Docker image with volume mount
  - [x] Update failure message with Docker command examples

- [x] Test validation workflows
  - [x] Trigger config-validation workflow manually with config.yaml
  - [x] Verify Docker image extraction works correctly
  - [x] Verify Docker pull succeeds with GITHUB_TOKEN auth
  - [x] Verify validation runs successfully
  - [x] Verify validation failures are reported correctly
  - [x] Test with both example configs (ci-test, dev, prod)
  - [x] Deploy ci-test environment to verify end-to-end functionality

- [ ] Verify no regressions
  - [ ] Existing valid configs still pass validation
  - [ ] Invalid configs still fail with clear error messages
  - [ ] Workflow execution time is acceptable
  - [ ] All CI checks pass on PR

## Implementation Order

Tasks should be completed in the order listed above:
1. Update terraform-deploy.yml first (primary deployment workflow)
2. Update config-validation.yml second (standalone validation)
3. Test both workflows thoroughly
4. Verify no regressions before merging

## Validation Checkpoints

After each workflow update:
- ✅ Workflow syntax is valid (GitHub Actions validates YAML)
- ✅ Docker commands extract correct image tag
- ✅ Volume mount path is correct for config file
- ✅ Validation output is visible in workflow logs
- ✅ Workflow fails appropriately on validation errors

## Dependencies

- None (all tasks are in this repository)

## Rollback Plan

If Docker-based validation fails:
1. Revert workflow changes
2. Restore UV/pip-based validation
3. Investigate Docker image or authentication issues
4. Fix root cause and retry

Rollback is low-risk since:
- Changes are isolated to CI workflows
- No infrastructure or application changes
- Easy to revert via git

## Issues Discovered During Testing

### Caddyfile Syntax Error (Fixed)

**Issue:** During ci-test deployment, Caddy failed to start due to incorrect Caddyfile syntax.

**Root Cause:** The `user_data.sh` script generated a Caddyfile with the `email` directive inside the site block:
```caddyfile
# INCORRECT
${DOMAIN_NAME} {
    reverse_proxy localhost:5000
    email ${SSL_EMAIL}  # Wrong location!
}
```

Caddy requires the `email` directive to be in a global options block, not inside a site block.

**Fix Applied:** Updated [user_data.sh](../../lablink-infrastructure/user_data.sh) lines 71-80 to generate correct syntax:
```caddyfile
# CORRECT
{
    email ${SSL_EMAIL}
}

${DOMAIN_NAME} {
    reverse_proxy localhost:5000
}
```

**Impact:** Without this fix, all Let's Encrypt deployments would fail with:
```
Error: adapting config using caddyfile: /etc/caddy/Caddyfile:4: unrecognized directive: email
```

**Testing:**
- ✅ Manually fixed Caddyfile on ci-test instance and verified Caddy starts
- ✅ Let's Encrypt successfully acquired SSL certificate
- ✅ HTTPS connectivity confirmed: https://ci-test.lablink-template-testing.com
- ✅ Updated user_data.sh to prevent issue in future deployments