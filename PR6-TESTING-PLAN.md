# PR #6 Pre-Merge Testing Plan

## Overview

This PR makes significant changes to configuration management and workflows. We need to thoroughly test all functionality before merging.

## What Changed in PR #6

### Configuration Changes
- ✅ Added `allocator.image_tag` to config.yaml
- ✅ Removed `terraform.tfvars`
- ✅ Hardcoded config path to `config/config.yaml`
- ✅ Added `DEBIAN_FRONTEND=noninteractive` to user_data.sh

### Workflow Changes
- ✅ Deploy workflow: Removed `image_tag` input, reads from config
- ✅ Destroy workflow: SSH-based client VM destruction
- ✅ Health check: Changed from port 5000 to port 80

### Infrastructure Changes
- ✅ EIP tagging: Made configurable via `eip.tag_name`
- ✅ Route53: Added dummy values for validation
- ✅ Locals: Added `allocator_image_tag` from config

## Pre-Merge Testing Checklist

### Test 1: Deploy with test.config.yaml ⚡ CRITICAL

**Purpose:** Verify basic deployment works with new config structure

**Steps:**
```bash
# 1. Ensure you're on the PR branch
git checkout elizabeth/-remove-allocator-tag-from-dispatch-input
git pull origin elizabeth/-remove-allocator-tag-from-dispatch-input

# 2. Verify test.config.yaml is correct
cat lablink-infrastructure/config/test.config.yaml

# 3. Trigger deploy workflow via GitHub UI
# Go to: Actions → Deploy LabLink Infrastructure → Run workflow
# Environment: test
# (No image_tag input - should read from config!)

# 4. Monitor deployment
# Watch: https://github.com/talmolab/lablink-template/actions/workflows/terraform-deploy.yml
```

**What to verify:**
- [ ] Workflow runs without errors
- [ ] Config secrets injected correctly
- [ ] Terraform reads `allocator.image_tag` from config.yaml
- [ ] Allocator container starts successfully
- [ ] Health check passes on port 80 (not 5000)
- [ ] Docker image tag matches config: `linux-amd64-latest-test`

**Expected behavior:**
- Deploy succeeds
- Allocator accessible at `http://<PUBLIC_IP>`
- No interactive prompts block user_data.sh
- CloudWatch import step handles existing log groups

---

### Test 2: Verify Allocator Image Tag ⚡ CRITICAL

**Purpose:** Confirm allocator uses image_tag from config

**Steps:**
```bash
# 1. SSH into allocator instance
ssh -i <key> ubuntu@<ALLOCATOR_IP>

# 2. Check running container
sudo docker ps

# 3. Verify image tag
sudo docker inspect <container_id> | grep Image

# 4. Check config file on instance
sudo cat /etc/lablink-allocator/config.yaml | grep image_tag
```

**What to verify:**
- [ ] Container running with correct image tag from config
- [ ] Image tag is `linux-amd64-latest-test` (matches test.config.yaml)
- [ ] Config file on instance has correct allocator.image_tag

**Expected behavior:**
- Container image: `ghcr.io/talmolab/lablink-allocator-image:linux-amd64-latest-test`
- Config matches test.config.yaml

---

### Test 3: EIP Tagging ⚡ CRITICAL

**Purpose:** Verify EIP is tagged correctly per config

**Steps:**
```bash
# 1. Check AWS console or CLI for EIP tags
aws ec2 describe-addresses --region us-west-2 \
  --filters "Name=tag:Environment,Values=test"

# 2. Verify tag name matches config
# test.config.yaml has: tag_name: "lablink-eip-dynamic"
# Expected tag: lablink-eip-dynamic-test
```

**What to verify:**
- [ ] EIP exists with tag: `lablink-eip-dynamic-test`
- [ ] Tag format: `{tag_name}-{env}`
- [ ] Strategy: dynamic (creates new EIP)

**Expected behavior:**
- New EIP created with correct tag
- Tag matches config.yaml `eip.tag_name`

---

### Test 4: Health Check Port ⚡ CRITICAL

**Purpose:** Verify health check uses port 80 via Caddy

**Steps:**
```bash
# 1. Get public IP from terraform output
PUBLIC_IP=$(terraform output -raw ec2_public_ip)

# 2. Test port 80 (should work via Caddy)
curl -v http://$PUBLIC_IP

# 3. Test port 5000 (should NOT work - not exposed)
curl -v http://$PUBLIC_IP:5000

# 4. On allocator instance, check Caddy
ssh ubuntu@$PUBLIC_IP
sudo systemctl status caddy
sudo cat /etc/caddy/Caddyfile
```

**What to verify:**
- [ ] Port 80 responds (proxied via Caddy)
- [ ] Port 5000 NOT accessible externally
- [ ] Caddy running and configured correctly
- [ ] Health check in workflow passes

**Expected behavior:**
- `http://<PUBLIC_IP>` returns 200 OK
- Caddy proxies to `localhost:5000`
- Allocator bound to `127.0.0.1:5000` (not exposed)

---

### Test 5: User Data Script ⚡ CRITICAL

**Purpose:** Verify Docker installation doesn't hang

**Steps:**
```bash
# 1. SSH into allocator
ssh ubuntu@<ALLOCATOR_IP>

# 2. Check cloud-init status
sudo cloud-init status --long

# 3. Check cloud-init logs
sudo tail -100 /var/log/cloud-init-output.log

# 4. Look for interactive prompts (should be none)
sudo grep -i "docker" /var/log/cloud-init-output.log
```

**What to verify:**
- [ ] `cloud-init status` shows "done" (not "running")
- [ ] No "Configuring docker.io" interactive prompts
- [ ] Docker installed successfully
- [ ] No hung apt processes

**Expected behavior:**
- cloud-init completes successfully
- `DEBIAN_FRONTEND=noninteractive` prevents prompts
- Docker installs without interaction

---

### Test 6: Destroy Workflow ⚡ CRITICAL

**Purpose:** Verify SSH-based client VM destruction works

**Steps:**
```bash
# 1. Launch a client VM via allocator UI
# Visit: http://<PUBLIC_IP>
# Launch 1 client VM

# 2. Verify client VM exists
# Check AWS console or:
aws ec2 describe-instances --region us-west-2 \
  --filters "Name=tag:Environment,Values=test" "Name=instance-state-name,Values=running"

# 3. Trigger destroy workflow
# Go to: Actions → Destroy LabLink Infrastructure → Run workflow
# Environment: test

# 4. Monitor destroy process
```

**What to verify:**
- [ ] Workflow SSHs into allocator successfully
- [ ] Finds allocator container by image name
- [ ] Runs terraform destroy inside container
- [ ] Client VMs destroyed
- [ ] Allocator infrastructure destroyed
- [ ] EIP released (dynamic strategy)
- [ ] No orphaned resources

**Expected behavior:**
- Client VMs destroyed via SSH approach
- Allocator EC2 terminated
- EIP released
- Clean destroy with no errors

---

### Test 7: Config Validation

**Purpose:** Verify terraform validate works with new config

**Steps:**
```bash
cd lablink-infrastructure

# 1. Run terraform validate locally
terraform init -backend=false
terraform validate

# 2. Test with different configs
cp config/test.config.yaml config/config.yaml
terraform validate

cp config/example.config.yaml config/config.yaml
# Update placeholders first
sed -i '' 's/PLACEHOLDER_ADMIN_PASSWORD/test/g' config/config.yaml
sed -i '' 's/PLACEHOLDER_DB_PASSWORD/test/g' config/config.yaml
terraform validate
```

**What to verify:**
- [ ] Terraform validate passes
- [ ] All locals defined correctly
- [ ] No undefined references
- [ ] Copilot test script passes

**Expected behavior:**
- `terraform validate` succeeds
- No syntax errors
- All config fields accessible

---

### Test 8: Documentation Accuracy

**Purpose:** Verify docs match implementation

**Steps:**
```bash
# 1. Review README.md
# Check allocator.image_tag documentation

# 2. Review DEPLOYMENT_CHECKLIST.md
# Check EIP tagging documentation

# 3. Verify examples match reality
# Check config/example.config.yaml
```

**What to verify:**
- [ ] README documents allocator.image_tag
- [ ] DEPLOYMENT_CHECKLIST has correct EIP tag format
- [ ] example.config.yaml has all required fields
- [ ] No references to removed terraform.tfvars

**Expected behavior:**
- All docs accurate and up-to-date
- Examples work as documented

---

## Testing Order

**Recommended sequence:**

1. ✅ **Run Copilot test script** (already done, all passed)
2. ⚡ **Test 1: Deploy** - Most critical, validates everything
3. ⚡ **Test 2: Image Tag** - While deployed, verify config works
4. ⚡ **Test 3: EIP Tagging** - Quick check of tags
5. ⚡ **Test 4: Health Check** - Verify port 80 works
6. ⚡ **Test 5: User Data** - Check cloud-init completed
7. ⚡ **Test 6: Destroy** - Test cleanup works
8. ✅ **Test 7: Config Validation** - Can do locally
9. ✅ **Test 8: Documentation** - Review only

## Known Issues to Watch For

### Issue: Caddy http://N/A Bug
**Status:** Known issue when DNS disabled
**Impact:** Allocator may not be accessible at public IP
**Workaround:** Already tracked in Issue #7
**For testing:** If allocator not accessible, this is a known bug

### Issue: CloudWatch Log Groups
**Status:** Fixed in PR #6 with import step
**Impact:** Deployment fails if log groups exist
**For testing:** Should auto-import existing log groups

### Issue: Docker Interactive Prompt
**Status:** Fixed in PR #6 with DEBIAN_FRONTEND
**Impact:** user_data.sh hangs on Docker install
**For testing:** Should complete without hanging

## Success Criteria

**PR #6 is ready to merge when:**

- [ ] Deploy workflow succeeds end-to-end
- [ ] Allocator accessible and functional
- [ ] Image tag read from config correctly
- [ ] EIP tagged correctly
- [ ] Health check passes on port 80
- [ ] user_data.sh completes without hanging
- [ ] Destroy workflow cleans up all resources
- [ ] No orphaned AWS resources after destroy
- [ ] All documentation accurate

## Rollback Plan

**If testing reveals critical issues:**

1. Document the issue in PR #6 comments
2. Create new issue for the problem
3. Decide: Fix in PR #6 or fix in follow-up PR
4. If blocking: Don't merge, fix first
5. If not blocking: Merge with known issues documented

## After Successful Testing

1. ✅ Update PR #6 with test results
2. ✅ Create issues for CI improvements
3. ✅ Merge PR #6
4. ✅ Monitor first production deployment
5. ✅ Close resolved issues #4 and #5

---

**Ready to test?** Start with Test 1 (Deploy) and work through the checklist!
