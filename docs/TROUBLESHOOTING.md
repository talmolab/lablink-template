# Troubleshooting

First stop when a deploy fails or the allocator is unreachable. Two companions:

- **[MANUAL_CLEANUP_GUIDE.md](MANUAL_CLEANUP_GUIDE.md)** — step-by-step recovery from
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

The script reads `deployment_name`, `bucket_name`, `region` and `eip.strategy` from `config.yaml`, backs up OpenTofu state files, and deletes resources in the correct dependency order.

Resources are named `{deployment_name}-{resource}-{environment}`, so the script needs the right `deployment_name`. The deploy workflow pins its own from the workflow input without writing it back to the committed config, so recovering a CI deploy usually needs the override:

```bash
./scripts/cleanup-orphaned-resources.sh <environment> --deployment-name YOUR-DEPLOYMENT --dry-run
```

**`0 deleted` with a long list of `not found` means the deployment name is wrong**, not that the environment is clean. For detailed manual cleanup procedures, see [MANUAL_CLEANUP_GUIDE.md](MANUAL_CLEANUP_GUIDE.md).

## Deployment Fails with "InvalidAMI"

**Cause**: AMI IDs are region-scoped, and the AMI named does not exist in the region
`app.region` selects. There are two separate AMIs, overridden in different places:

| AMI | Used by | Override with |
|-----|---------|---------------|
| Allocator | OpenTofu, at apply | `-var="allocator_ami_id=ami-..."` |
| Client | the allocator, when provisioning VMs | `machine.ami_id` in `config.yaml` |

**Solution**: copy an equivalent image into your region and supply it. Both bundled
images are custom builds with Docker pre-installed — `user_data.sh` starts the Docker
daemon rather than installing it, so a stock Ubuntu AMI is not a substitute.

```bash
aws ec2 copy-image --source-region us-west-2 \
  --source-image-id ami-0bd08c9d4aa9f0bc6 \
  --region YOUR-REGION --name lablink-allocator-ubuntu24-docker
```

Changing `app.region` without an allocator AMI for that region is caught at plan time
with an explanatory error, so it fails before creating anything. A client AMI mismatch
cannot be caught that way — the allocator uses it at runtime, so it surfaces as a
failed VM launch in the admin UI rather than a failed apply.

See [Deploying outside us-west-2](../lablink-infrastructure/README.md#deploying-outside-us-west-2).

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
- **Deployment Checklist**: [DEPLOYMENT_CHECKLIST.md](DEPLOYMENT_CHECKLIST.md)
