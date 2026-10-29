# ==============================================================================
# Remote state
# ==============================================================================
# State for this stack lives in S3 and is encrypted at rest. The bucket, key,
# and region are supplied at init time so no account details live in code:
#
#   terraform init -backend-config=backend.hcl
#
# See backend.hcl.example for the expected values.
# ==============================================================================
terraform {
  backend "s3" {
    encrypt = true
  }
}

# ------------------------------------------------------------------------------
# Bootstrap outputs
# ------------------------------------------------------------------------------
# Reads the EKS cluster and node role ARNs exported by infra/bootstrap, so this
# stack never creates or modifies IAM roles itself.
# ------------------------------------------------------------------------------
data "terraform_remote_state" "bootstrap" {
  backend = "s3"

  config = {
    bucket = var.bootstrap_state_bucket_name
    key    = var.bootstrap_state_file_key
    region = var.aws_region
  }
}
