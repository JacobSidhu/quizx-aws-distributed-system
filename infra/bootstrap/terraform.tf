# ------------------------------------------------------------------------------
# Terraform and provider requirements
# ------------------------------------------------------------------------------
# The AWS provider is pinned to the 5.x major version so a provider upgrade is
# always a deliberate change. Exact versions are locked in .terraform.lock.hcl.
# Terraform 1.10+ is required for S3-native state locking (see main.tf).
# ------------------------------------------------------------------------------
terraform {

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
  required_version = ">= 1.10.0"
}

# ------------------------------------------------------------------------------
# AWS provider
# ------------------------------------------------------------------------------
# Bootstrap runs with the caller's own credentials (in CI, the GitHub OIDC
# bootstrap role). Unlike infra/terraform, it does not assume the Terraform
# execution role, because this stack is what creates that role.
#
# default_tags applies the standard Project/Environment/ManagedBy tags to every
# taggable resource, which the tag-based IAM conditions below rely on.
# ------------------------------------------------------------------------------
provider "aws" {
  region = var.aws_region
  default_tags {
    tags = local.common_tags
  }
}
