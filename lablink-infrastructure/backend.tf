terraform {
  # OpenTofu 1.12.5 is what CI pins and what the `lablink` CLI expects.
  #
  # The floor is 1.10.0. Below it, a retried S3 state upload can fail *after*
  # the apply already ran, leaving the tool to continue against stale state.
  # The root cause is aws/aws-sdk-go-v2#2485 (the PutObject body is left
  # non-seekable) and the Terraform fix for it, hashicorp/terraform#34796
  # released in 1.7.5, was a pure SDK bump and nothing else.
  #
  # Exposure is therefore decided by the vendored SDK, not the release number.
  # OpenTofu did not dodge this by forking early: it pinned aws-sdk-go-v2
  # v1.23.2 from 1.6.0 through 1.9.x, short of the v1.25.3 carrying the fix,
  # and its s3/client.go uses the same PutObject + bytes.NewReader path the
  # bug was reported against. 1.10.0 is the first release past it (v1.36.0).
  # Do not translate Terraform's old 1.9.0 floor across by number.
  #
  # Why this constraint still bites even though OpenTofu 1.12 ignores
  # required_version in a `terraform {}` block (it reads such blocks as
  # Terraform-targeted): the versions being excluded are exactly the ones that
  # still enforce it. Verified against real binaries —
  #
  #   OpenTofu 1.9.1  -> Error: Unsupported OpenTofu Core version
  #   OpenTofu 1.12.5 -> initializes fine
  #   Terraform 1.9.6 -> Error: Unsupported Terraform Core version
  #
  # so old OpenTofu is refused, current OpenTofu passes, and any Terraform
  # still pointed here must be 1.10+. Rollback to Terraform remains possible
  # (state is format v4 both ways; Terraform 1.9.6 reads and rewrites
  # OpenTofu-written state), it just has to use Terraform 1.10 or newer.
  #
  # Keep in step with MIN_OPENTOFU_VERSION in talmolab/lablink's
  # packages/cli/src/lablink_cli/commands/doctor.py and the allocator's
  # terraform/versions.tf.
  #
  # The block is still named `terraform` because that is the label OpenTofu
  # reads; it is not a reference to the Terraform binary.
  required_version = ">= 1.10.0, < 2.0.0"

  backend "s3" {}
}
# The backend configuration is intentionally left empty.
# It will be populated by the `tofu init` command.
# This allows the backend to be configured dynamically based on the environment.
