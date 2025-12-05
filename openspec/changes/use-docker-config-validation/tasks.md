# Implementation Tasks

## Task List

- [ ] Update terraform-deploy.yml workflow
  - [ ] Remove UV setup step
  - [ ] Add Docker login step for GHCR authentication
  - [ ] Replace pip-based validation with Docker-based validation
  - [ ] Extract `allocator.image_tag` from config.yaml
  - [ ] Pull allocator Docker image
  - [ ] Run validator using Docker image with volume mount

- [ ] Update config-validation.yml workflow
  - [ ] Remove UV setup step
  - [ ] Remove temp project creation step
  - [ ] Add Docker login step for GHCR authentication
  - [ ] Replace pip-based validation with Docker-based validation
  - [ ] Extract `allocator.image_tag` from config file path
  - [ ] Pull allocator Docker image
  - [ ] Run validator using Docker image with volume mount
  - [ ] Update failure message with Docker command examples

- [ ] Test validation workflows
  - [ ] Trigger config-validation workflow manually with config.yaml
  - [ ] Verify Docker image extraction works correctly
  - [ ] Verify Docker pull succeeds with GITHUB_TOKEN auth
  - [ ] Verify validation runs successfully
  - [ ] Verify validation failures are reported correctly
  - [ ] Test with both example configs (ci-test, dev, prod)

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