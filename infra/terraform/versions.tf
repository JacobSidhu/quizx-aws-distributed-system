# ==============================================================================
# Terraform and provider versions
# ==============================================================================
# The AWS provider is pinned to the 6.x major version so a provider upgrade is
# always a deliberate change. Exact versions are locked in .terraform.lock.hcl.
# ==============================================================================
terraform {
  required_version = ">= 1.6.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }
}
