# ==============================================================================
# Input variables
# ==============================================================================
# Values without a default must be supplied, usually via terraform.tfvars
# (see terraform.tfvars.example) or TF_VAR_* environment variables in CI.
# ==============================================================================

# ------------------------------------------------------------------------------
# Project and environment
# ------------------------------------------------------------------------------
variable "project_name" {
  description = "Name of the project"
  type        = string
  default     = "quizx"
}

variable "environment" {
  description = "Deployment environment used in AWS resource names and tags"
  type        = string
  default     = "dev"

  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "environment must be dev, staging, or prod."
  }
}

variable "managedby" {
  description = "Value of the standard ManagedBy tag"
  type        = string
  default     = "Terraform"
}

# ------------------------------------------------------------------------------
# AWS account and region
# ------------------------------------------------------------------------------
variable "aws_region" {
  description = "AWS region where infrastructure will be deployed"
  type        = string
  default     = "eu-west-2"
}

variable "aws_account_id" {
  description = "AWS account ID where the resources will be created"
  type        = string

  validation {
    condition     = can(regex("^[0-9]{12}$", var.aws_account_id))
    error_message = "aws_account_id must be a 12-digit AWS account ID."
  }
}

# ------------------------------------------------------------------------------
# Terraform state locations
# ------------------------------------------------------------------------------
# Used to scope the caller policy to exactly these state objects. They must
# match the backend settings used at init time.
# ------------------------------------------------------------------------------
variable "tf_bootstrap_state_bucket_name" {
  description = "Name of the S3 bucket for Terraform state storage"
  type        = string
  default     = "quizx-terraform-state"
}

variable "tf_bootstrap_state_key" {
  description = "S3 object key used for the bootstrap Terraform state"
  type        = string
  default     = "terraform/quizx/state/bootstrap/terraform.tfstate"
}

variable "tf_main_state_bucket_name" {
  description = "S3 bucket for main infrastructure state; defaults to the bootstrap state bucket"
  type        = string
  default     = null
}

variable "tf_main_state_key" {
  description = "S3 object key used for the main infrastructure Terraform state"
  type        = string
  default     = "terraform/quizx/state/infra/terraform.tfstate"
}

# ------------------------------------------------------------------------------
# IAM identities
# ------------------------------------------------------------------------------
variable "quizx_iam_user" {
  description = "IAM user for Terraform automation"
  type        = string

  validation {
    condition     = length(trimspace(var.quizx_iam_user)) > 0
    error_message = "quizx_iam_user must not be empty."
  }
}

variable "terraform_execution_role_name" {
  description = "Name of the IAM role assumed by Terraform"
  type        = string

  validation {
    condition     = length(trimspace(var.terraform_execution_role_name)) > 0
    error_message = "terraform_execution_role_name must not be empty."
  }
}

variable "eks_cluster_role_name" {
  description = "Name of the IAM role assumed by the EKS control plane"
  type        = string

  validation {
    condition     = length(trimspace(var.eks_cluster_role_name)) > 0
    error_message = "eks_cluster_role_name must not be empty."
  }
}

variable "eks_node_role_name" {
  description = "Name of the IAM role assumed by EKS worker nodes"
  type        = string

  validation {
    condition     = length(trimspace(var.eks_node_role_name)) > 0
    error_message = "eks_node_role_name must not be empty."
  }
}
