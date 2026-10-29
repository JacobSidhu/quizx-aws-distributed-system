# ==============================================================================
# AWS provider
# ==============================================================================
# The caller's credentials are only used to assume the Terraform execution role
# created by infra/bootstrap. Every resource in this stack is then created with
# that role's scoped, per-service permissions.
#
# default_tags applies the standard Project / Environment / ManagedBy tags to
# every taggable resource. The execution role's IAM conditions rely on these
# tags, so they must not be removed.
# ==============================================================================
provider "aws" {
  region = var.aws_region

  default_tags {
    tags = local.common_tags
  }

  assume_role {
    role_arn = "arn:aws:iam::${var.aws_account_id}:role/${var.terraform_execution_role_name}"
  }
}
