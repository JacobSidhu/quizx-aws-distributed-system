variable "aws_region" {
  description = "AWS region where infrastructure will be deployed"
  type        = string
  default     = "eu-west-2"
}

variable "tf_bootstrap_state_bucket_name" {
  description = "Name of the S3 bucket for Terraform state storage"
  type        = string
  default     = "quizx-terraform-state"
}

variable "aws_account_id" {
  description = "AWS account ID where the resources will be created"
  type        = string
  default     = null
}

variable "quizx_iam_user" {
  description = "IAM user for Terraform automation"
  type        = string
  default     = null
}

variable "quizx_iam_role" {
  description = "IAM role for Terraform automation"
  type        = string
  default     = null
}