terraform {
  # OpenTofu 1.12.5 is what CI pins and what the `lablink` CLI expects. The
  # floor stays at 1.9.0 because this repo migrated from Terraform, and any
  # Terraform binary still pointed at this config must be new enough to avoid
  # hashicorp/terraform#34528 — an aws-sdk-go-v2 bug below the 1.8.0 line that
  # leaves the PutObject body non-seekable, so a retried state upload fails
  # *after* the apply already ran and the tool continues against stale state.
  # OpenTofu forked before that bug was introduced and has no reports of it.
  #
  # The block is still named `terraform` because that is the label OpenTofu
  # reads; it is not a reference to the Terraform binary.
  required_version = ">= 1.9.0, < 2.0.0"

  backend "s3" {}
}
# The backend configuration is intentionally left empty.
# It will be populated by the `tofu init` command.
# This allows the backend to be configured dynamically based on the environment.
