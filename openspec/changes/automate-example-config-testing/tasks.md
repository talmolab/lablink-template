# Implementation Tasks: Automate Example Config Testing

## Phase 1: Terraform Plan Validation (Low Risk, Low Cost)

- [ ] Create workflow file `.github/workflows/test-example-configs.yml`
  - [ ] Set up workflow triggers (PR paths, workflow_dispatch, schedule)
  - [ ] Configure permissions (id-token: write, contents: read)
  - [ ] Add workflow_dispatch inputs for manual config selection

- [ ] Implement terraform-plan-validation job
  - [ ] Define matrix strategy with all example config files
  - [ ] Add checkout step
  - [ ] Add AWS OIDC authentication step (reuse existing secrets)
  - [ ] Add Terraform setup step (version 1.6.6)
  - [ ] Add step to copy matrix config to config.yaml
  - [ ] Add step to inject placeholder passwords for plan
  - [ ] Add terraform init step with ci-test backend
  - [ ] Add terraform plan step with ci-test-plan-check suffix
  - [ ] Add step to report plan success/failure

- [ ] Test terraform plan validation locally
  - [ ] Manually copy ip-only.example.yaml to config.yaml
  - [ ] Run terraform init with ci-test backend
  - [ ] Run terraform plan with dummy suffix
  - [ ] Verify plan succeeds

- [ ] Create test PR to verify workflow runs
  - [ ] Make trivial change to an example config
  - [ ] Verify workflow triggers on PR
  - [ ] Verify all configs pass terraform plan
  - [ ] Verify clear output for each config tested

## Phase 2: Smoke Test Deployment (Higher Risk, Manage Costs)

- [ ] Add smoke-test-deployment job to workflow
  - [ ] Set job dependency: needs terraform-plan-validation
  - [ ] Add conditional trigger logic (schedule, workflow_dispatch, test-deploy label)
  - [ ] Define matrix strategy (ip-only.example.yaml, letsencrypt.example.yaml)
  - [ ] Add checkout and AWS authentication steps
  - [ ] Add Terraform setup step

- [ ] Implement config preparation for smoke tests
  - [ ] Copy matrix config to config.yaml
  - [ ] For letsencrypt configs: modify to use staging environment
  - [ ] Inject real password secrets (ADMIN_PASSWORD, DB_PASSWORD)
  - [ ] Extract bucket_name from config for backend config

- [ ] Implement deployment steps
  - [ ] Run terraform init with ci-test backend and unique state key
  - [ ] Run terraform apply with unique suffix: ci-test-${{ github.run_id }}-${{ strategy.job-index }}
  - [ ] Capture terraform outputs (allocator_fqdn, ec2_public_ip)
  - [ ] Mark step with continue-on-error for cleanup handling

- [ ] Implement health check steps
  - [ ] Wait 60 seconds for allocator container to start
  - [ ] Test HTTP endpoint (allocator FQDN or IP)
  - [ ] Verify HTTP 200 response (allow up to 2 minutes with retries)
  - [ ] For Let's Encrypt configs: optionally verify SSL (staging cert)
  - [ ] Report health check results

- [ ] Implement cleanup/destroy steps
  - [ ] Run terraform destroy -auto-approve (always, even on failure)
  - [ ] Verify destroy completes successfully
  - [ ] Report destroy status

- [ ] Add result reporting steps
  - [ ] Log deployment duration
  - [ ] Log health check wait time
  - [ ] Log destroy duration
  - [ ] Report overall success/failure

## Phase 3: Testing and Validation

- [ ] Test smoke deployment manually via workflow_dispatch
  - [ ] Select ip-only.example.yaml only
  - [ ] Verify deployment succeeds
  - [ ] Verify unique resource naming (check AWS console)
  - [ ] Verify health check passes
  - [ ] Verify destroy cleans up all resources
  - [ ] Check AWS costs (~$2-3 for single test)

- [ ] Test Let's Encrypt staging environment handling
  - [ ] Trigger workflow with letsencrypt.example.yaml
  - [ ] Verify staging environment is used (check Caddy logs if possible)
  - [ ] Verify no production Let's Encrypt cert is requested
  - [ ] Confirm untrusted staging cert is obtained
  - [ ] Verify destroy completes

- [ ] Test parallel execution (if implementing)
  - [ ] Trigger workflow with both configs
  - [ ] Verify unique resource suffixes prevent conflicts
  - [ ] Verify both can deploy simultaneously
  - [ ] Verify both clean up correctly

- [ ] Test failure scenarios
  - [ ] Introduce intentional terraform error in example config
  - [ ] Verify terraform plan validation catches it
  - [ ] Verify clear error message in CI output
  - [ ] Fix error and verify re-run succeeds

- [ ] Test scheduled weekly run
  - [ ] Update schedule cron to run sooner for testing
  - [ ] Wait for scheduled run to execute
  - [ ] Verify both configs tested
  - [ ] Verify costs are reasonable
  - [ ] Reset schedule to Sunday 2 AM UTC

## Phase 4: Documentation and Polish

- [ ] Update README.md
  - [ ] Add section on automated config testing in CI
  - [ ] Link to workflow file
  - [ ] Explain what configs are tested and when
  - [ ] Mention cost and rate limit considerations

- [ ] Update docs/TESTING_BEST_PRACTICES.md
  - [ ] Add section on CI automated testing
  - [ ] Explain multi-level testing strategy
  - [ ] Document how to trigger manual tests
  - [ ] Document how to add test-deploy label to PR
  - [ ] Explain cost optimization approach

- [ ] Add comments to example configs (optional)
  - [ ] Note which configs are tested in CI automatically
  - [ ] Mention Let's Encrypt staging environment used in CI
  - [ ] Link to workflow file for reference

- [ ] Create troubleshooting guide
  - [ ] Document common CI test failures
  - [ ] How to debug terraform plan failures
  - [ ] How to debug deployment failures
  - [ ] How to manually clean up stuck resources
  - [ ] When to use test-deploy label

## Phase 5: Monitoring and Iteration

- [ ] Monitor first week of automated testing
  - [ ] Track CI workflow execution times
  - [ ] Monitor AWS costs in billing dashboard
  - [ ] Review test failure rate
  - [ ] Collect feedback from team

- [ ] Optimize based on results
  - [ ] Adjust timeouts if tests timing out
  - [ ] Tune health check retry logic if too aggressive/slow
  - [ ] Consider adding more configs to smoke tests if costs allow
  - [ ] Consider reducing schedule frequency if costs too high

- [ ] Plan future enhancements (out of scope for this change)
  - [ ] End-to-end VM provisioning testing (Level 4)
  - [ ] Cost reporting in PR comments
  - [ ] Terraform plan diff in PR comments
  - [ ] CloudFlare config testing (if credentials available)
  - [ ] ACM config testing (if certificates provisioned)

## Dependencies

**Prerequisites before starting:**
- [x] ci-test environment exists with backend-ci-test.hcl
- [x] GitHub secrets configured: AWS_ROLE_ARN, AWS_REGION, ADMIN_PASSWORD, DB_PASSWORD
- [x] S3 bucket exists for Terraform state (from config.yaml bucket_name)
- [x] Example configs validated with lablink-validate-config

**External dependencies:**
- GitHub Actions runners availability
- AWS service availability in configured region
- Let's Encrypt staging environment availability

## Validation Criteria

**For Phase 1 (terraform plan validation):**
- [ ] Workflow triggers on PR affecting infrastructure or config files
- [ ] All 10 example configs successfully pass terraform plan
- [ ] Failed plans show clear error messages
- [ ] Workflow completes in <20 minutes

**For Phase 2 (smoke test deployment):**
- [ ] Smoke tests deploy and destroy infrastructure successfully
- [ ] Health checks verify allocator service responds
- [ ] Let's Encrypt staging environment used (not production)
- [ ] Resources cleaned up completely (no orphans)
- [ ] Workflow completes in <30 minutes for both configs
- [ ] Cost per run is <$5

**For Phase 4 (documentation):**
- [ ] README.md explains CI testing strategy
- [ ] TESTING_BEST_PRACTICES.md covers automated testing
- [ ] Documentation is clear and actionable

**Overall success:**
- [ ] PRs get automatic terraform plan validation
- [ ] Weekly automated smoke tests catch regressions
- [ ] Maintainers can trigger on-demand comprehensive tests
- [ ] No new secrets or infrastructure required
- [ ] Monthly costs stay under $25 for automated testing