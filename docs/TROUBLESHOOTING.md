# Troubleshooting

First stop when a deploy fails or the allocator is unreachable. Two companions:

- **[MANUAL_CLEANUP_GUIDE.md](../MANUAL_CLEANUP_GUIDE.md)** — step-by-step recovery from
  failed destroys, orphaned resources, and corrupted OpenTofu state.
- **[lablink-infrastructure/README.md](../lablink-infrastructure/README.md#troubleshooting)** —
  runtime issues on a deployed allocator (Caddy/SSL logs, Docker container, DNS).

---

## Orphaned Resources After Failed Destroy

**Cause**: Destroy workflow failed or OpenTofu state is out of sync with AWS resources

**Solution**: Use the automated cleanup script:
```bash
# Dry-run to see what would be deleted
./scripts/cleanup-orphaned-resources.sh <environment> --dry-run

# Actual cleanup
./scripts/cleanup-orphaned-resources.sh <environment>
```

The script automatically reads configuration from `config.yaml`, backs up OpenTofu state files, and deletes resources in the correct dependency order. For detailed manual cleanup procedures, see [MANUAL_CLEANUP_GUIDE.md](../MANUAL_CLEANUP_GUIDE.md).

## Deployment Fails with "InvalidAMI"

**Cause**: AMI ID doesn't exist in your region

**Solution**: Update `ami_id` in `config.yaml` with a region-appropriate AMI

## Cannot Access Allocator Web Interface

**Cause**: Security group or DNS not configured

**Solution**:
1. Check security group allows inbound traffic on port 5000
2. If using DNS, verify DNS records propagated
3. Try accessing via public IP first

## OpenTofu State Lock Error

**Cause**: Previous deployment didn't complete or cleanup

**Solution**:
```bash
# In lablink-infrastructure/
tofu force-unlock LOCK_ID
```

## DNS Not Resolving

**Cause**: DNS propagation delay or Route 53 not configured

**Solution**:
1. Wait 5-10 minutes for propagation
2. Verify Route 53 hosted zone exists
3. Check nameservers match at domain registrar
4. Use `nslookup your-domain.com` to test

## More Help

- **Main Documentation**: https://talmolab.github.io/lablink/
- **Infrastructure Docs**: [lablink-infrastructure/README.md](../lablink-infrastructure/README.md)
- **Template issues**: https://github.com/talmolab/lablink-template/issues
- **LabLink issues**: https://github.com/talmolab/lablink/issues
- **Deployment Checklist**: [DEPLOYMENT_CHECKLIST.md](../DEPLOYMENT_CHECKLIST.md)
