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

**Cause**: AMI IDs are region-scoped, and `machine.ami_id` names an image that does not
exist in the region `app.region` selects. This is a **client** VM problem — the allocator
resolves its own AMI per region from an SSM parameter and cannot produce this error.

**Solution**: point `machine.ami_id` at a client image that exists in `app.region`:

| Region | Published client AMI |
|--------|---------------------|
| `us-west-2` | `ami-0601752c11b394251` |
| `us-east-1` | `ami-0c3412413810adacc` |
| `us-east-2` | `ami-0cd7567480c4840a0` |

In any other region, copy one of those into your own account (`aws ec2 copy-image`) and
use the new ID, or use an AWS Deep Learning Base AMI — the client image needs Docker and
the NVIDIA drivers baked in, so a plain Ubuntu AMI is not a substitute there.

Nothing catches this at plan time: the allocator uses `machine.ami_id` at runtime when it
provisions VMs, so a mismatch surfaces as a failed VM launch in the admin UI rather than a
failed apply. `scripts/doctor.sh` and `scripts/configure.sh` both validate the AMI against
the region, which is the cheapest place to catch it.

See [Regions and AMIs](../lablink-infrastructure/README.md#regions-and-amis).

## Desktop Sessions Feel Laggy

**Cause**: on an HTTP deployment (`ssl.provider: "none"`), the viewer cannot use H.264
video streaming. Chrome exposes the WebCodecs decoder only on secure origins, so the
codec probe logs `WebCodecs API not available` and every session falls back to JPEG/WebP
stills — each damaged screen region is re-encoded from scratch every frame instead of
encoding only the change between frames. Motion (window drags, scrolling plots, playback)
is where it shows.

The server side is not the problem: KasmVNC advertises H.264 and the encoder works. The
browser declines it.

**Solution**: configure an SSL provider (`letsencrypt`, `cloudflare` or `acm`) so the
viewer is served over HTTPS.

To confirm the diagnosis without a domain, port-forward the allocator and open it as
`localhost`, which counts as a secure origin:

```bash
ssh -i your-key.pem -L 8443:localhost:5000 ubuntu@ALLOCATOR_IP
# then open http://localhost:8443 and take a session
```

The viewer caches its codec verdict in `localStorage`, so use an incognito window after
switching origins or you will see the stale result. `scripts/doctor.sh` and
`lablink doctor` both flag an HTTP deployment for this reason.

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
