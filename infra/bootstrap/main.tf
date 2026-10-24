# ------------------------------------------------------------------------------
# Remote state backend
# ------------------------------------------------------------------------------
# State for this stack lives in S3 and is encrypted at rest. The bucket, key,
# and region are deliberately left out of the code and supplied at init time,
# so the same configuration can target any account or environment:
#
#   terraform init -backend-config=backend.hcl
#
# See backend.hcl.example for the expected values. The bootstrap state uses its
# own key, separate from the main infrastructure state in infra/terraform.
#
# use_lockfile enables S3-native state locking (Terraform 1.10+): a
# "<key>.tflock" object is held for the duration of a run, so two runs (for
# example CI and a workstation) can never write the state at the same time.
# No DynamoDB table is required.
# ------------------------------------------------------------------------------
terraform {
  backend "s3" {
    encrypt      = true
    use_lockfile = true
  }
}
