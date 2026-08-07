terraform {
  # Below the 1.8.0 line, the S3 backend can silently corrupt state. An
  # aws-sdk-go-v2 bug leaves the PutObject body non-seekable, so a retried
  # state upload fails with "failed to rewind transport stream for retry"
  # *after* the apply or destroy has already run — and terraform may then
  # continue against stale state, creating or deleting the wrong resources.
  # See hashicorp/terraform#34528, fixed by #34796.
  #
  # This matters most for operators running terraform from their own machine
  # (the `lablink` CLI does), where the binary is whatever they happen to have
  # installed. Refuse rather than risk the state file.
  required_version = ">= 1.9.0, < 2.0.0"

  backend "s3" {}
}
# The backend configuration is intentionally left empty.
# It will be populated by the `terraform init` command.
# This allows the backend to be configured dynamically based on the environment.
