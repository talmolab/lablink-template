# LabLink Infrastructure Template

A GitHub template repository for deploying [LabLink](https://github.com/talmolab/lablink)
to AWS with Terraform. Fork it, edit one config file, deploy via GitHub Actions.

## Repository Layout

- `lablink-infrastructure/` — Terraform for the allocator: `main.tf`, `alb.tf`,
  `backend.tf`, `backend-{dev,test,ci-test,prod}.hcl`, `user_data.sh`.
- `lablink-infrastructure/config/` — `config.yaml` plus `*.example.yaml` variants
  covering the DNS/SSL use cases.
- `scripts/` — setup, Terraform init, cost estimation, cleanup, and the
  `configure.sh` wizard that generates `config.yaml`.
- `.github/workflows/` — deploy, destroy, config validation, startup-script validation.
- `.claude/commands/` — repo-specific slash commands.

## Things That Will Bite You

**`config.yaml` is validated against the allocator's schema, and the schema is
strict.** It lives upstream in
`packages/allocator/src/lablink_allocator_service/conf/structured_config.py`. Any key
not in that dataclass makes the config fail outright — there is no "ignored extra
field". When upstream deletes a field, every config here must drop it too. Validate
before pushing:

```bash
docker run --rm -v "$(pwd)/lablink-infrastructure/config/config.yaml:/config/config.yaml:ro" \
  ghcr.io/talmolab/lablink-allocator-image:<image_tag> \
  uv run lablink-validate-config /config/config.yaml --verbose
```

`scripts/validate-all-configs.sh` runs this over every example config.

**`deployment_name` and `environment` must agree between `config.yaml` and the
Terraform `-var` values.** The allocator reads them from the config file (it is copied
verbatim onto the instance by `user_data.sh`) and scopes its client Terraform state to
`s3://{bucket}/{deployment_name}/{environment}/`. The instance profile grants exactly
that prefix and nothing else, so a mismatch produces AccessDenied when the allocator
provisions client VMs — long after a green `terraform apply`. The deploy workflow pins
both fields from the same inputs it passes to `-var`; keep it that way.

**Editing `config.yaml` replaces the allocator EC2 instance.** Its contents feed
`CONFIG_CONTENT` into `user_data_base64`, and that forces replacement. Expect downtime
on apply. A persistent EIP keeps the address stable across the replacement.

**Config path is hardcoded.** `lablink-infrastructure/config/config.yaml` — do not move
or rename it.

**Secrets are never committed.** `config.yaml` carries `PLACEHOLDER_ADMIN_PASSWORD` and
`PLACEHOLDER_DB_PASSWORD`; the deploy workflow substitutes them from GitHub secrets and
hard-fails if the placeholders are absent, so keep them in any config you hand-write.

## Conventions

- **Terraform**: `>= 1.9.0, < 2.0.0` (CI pins 1.9.8). Run `terraform fmt` before
  committing — CI enforces `terraform fmt -check`.
- **Resource naming**: `{deployment_name}-{resource-type}-{environment}`, kebab-case
  throughout. Environments: `dev`, `test`, `ci-test`, `prod`.
- **Bash**: `set -e`, validate prerequisites up front, idempotent where practical.
- **Branches**: `main` is production-ready; pushing to `test` auto-deploys the test
  environment. Destroys are manual and require explicit confirmation.

## When Adding Features

Update the docs that ship with the change: `README.md` for user-facing configuration,
`DEPLOYMENT_CHECKLIST.md` for anything that alters deploy steps, and
`lablink-infrastructure/config/README.md` for schema changes.
