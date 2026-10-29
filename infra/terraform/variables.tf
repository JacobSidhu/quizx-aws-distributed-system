# ==============================================================================
# Input variables
# ==============================================================================
# Values are supplied through terraform.tfvars (git-ignored, see
# terraform.tfvars.example) or as TF_VAR_* environment variables in CI.
# ==============================================================================

# ------------------------------------------------------------------------------
# Project and environment
# ------------------------------------------------------------------------------
variable "project_name" {
  description = "Project name used in resource names and tags"
  type        = string
  default     = "quizx"
}

variable "environment" {
  description = "Deployment environment used in resource names and tags"
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
variable "aws_account_id" {
  description = "AWS account ID used to build the Terraform execution role ARN"
  type        = string

  validation {
    condition     = can(regex("^[0-9]{12}$", var.aws_account_id))
    error_message = "aws_account_id must be a 12-digit AWS account ID."
  }
}

variable "aws_region" {
  description = "AWS region the infrastructure is deployed to"
  type        = string
  default     = "eu-west-2"
}

# ------------------------------------------------------------------------------
# Terraform execution and bootstrap state
# ------------------------------------------------------------------------------
variable "terraform_execution_role_name" {
  description = "Name of the IAM role, created by infra/bootstrap, that the AWS provider assumes"
  type        = string

  validation {
    condition     = length(trimspace(var.terraform_execution_role_name)) > 0
    error_message = "terraform_execution_role_name must not be empty."
  }
}

variable "bootstrap_state_bucket_name" {
  description = "S3 bucket holding the infra/bootstrap state (read for the EKS role ARNs)"
  type        = string
  default     = null
}

variable "bootstrap_state_file_key" {
  description = "S3 object key of the infra/bootstrap state file"
  type        = string
  default     = null
}

# ------------------------------------------------------------------------------
# Networking
# ------------------------------------------------------------------------------
variable "networking" {
  description = "VPC CIDR, DNS settings, availability zones, and subnet CIDRs (two of each subnet type)"
  type = object({
    vpc_cidr             = string
    enable_dns_support   = bool
    enable_dns_hostnames = bool
    availability_zones   = list(string)
    public_subnet_cidrs  = list(string)
    private_subnet_cidrs = list(string)
  })

  default = {
    vpc_cidr             = "10.0.0.0/16"
    enable_dns_support   = true
    enable_dns_hostnames = true
    availability_zones   = ["eu-west-2a", "eu-west-2b"]
    public_subnet_cidrs  = ["10.0.1.0/24", "10.0.2.0/24"]
    private_subnet_cidrs = ["10.0.3.0/24", "10.0.4.0/24"]
  }
}

variable "public_route_config" {
  description = "Destination CIDR of the public route table's internet gateway route"
  type = object({
    cidr_block = string
  })
}

# ------------------------------------------------------------------------------
# External access and service ports
# ------------------------------------------------------------------------------
variable "access" {
  description = "CIDR blocks allowed to reach SSH and the two application ports"
  type = object({
    ssh_cidr          = string
    question_app_cidr = string
    submit_app_cidr   = string
  })
}

variable "service_ports" {
  description = "Ports used by SSH, the applications, the ALB, RDS, and the VPC link"
  type = object({
    ssh          = number
    question_app = number
    submit_app   = number
    alb          = number
    rds          = number
    vpc_link     = number
  })
}

# ------------------------------------------------------------------------------
# EC2 instances
# ------------------------------------------------------------------------------
variable "instance_type" {
  description = "EC2 instance type for the application servers"
  type        = string
  default     = "t3.micro"
}

variable "aws_ami_id" {
  description = "AMI ID for the application servers (Ubuntu; user-data.sh uses apt)"
  type        = string
  default     = null

  validation {
    condition     = var.aws_ami_id != null && can(regex("^ami-[0-9a-fA-F]{8,17}$", var.aws_ami_id))
    error_message = "aws_ami_id must be a real AMI ID, for example ami-0123456789abcdef0; replace the ami-xxxxxxxxxxxxxxxxx placeholder."
  }
}

variable "ssh_public_key" {
  description = "Public key registered as the EC2 key pair"
  type        = string
  sensitive   = true
}

# ------------------------------------------------------------------------------
# RDS
# ------------------------------------------------------------------------------
variable "rds_master_password" {
  description = "Master user password for the RDS MySQL instance"
  type        = string
  sensitive   = true
}

# ------------------------------------------------------------------------------
# Custom domain
# ------------------------------------------------------------------------------
variable "enable_custom_domain" {
  description = "Whether to create the ACM certificate and API Gateway custom domain"
  type        = bool
  default     = false
}

variable "domain_name" {
  description = "Root domain, registered with GoDaddy, that hosts the API subdomain"
  type        = string
  default     = null

  validation {
    condition = (
      !var.enable_custom_domain ||
      can(regex("^[A-Za-z0-9](?:[A-Za-z0-9-]{0,61}[A-Za-z0-9])?(?:\\.[A-Za-z0-9](?:[A-Za-z0-9-]{0,61}[A-Za-z0-9])?)+$", coalesce(var.domain_name, "")))
    )
    error_message = "domain_name must be set to a valid root domain such as example.com when enable_custom_domain is true."
  }
}

variable "api_subdomain" {
  description = "Subdomain used for the QuizX API"
  type        = string
  default     = "quizx"

  validation {
    condition     = can(regex("^[A-Za-z0-9](?:[A-Za-z0-9-]{0,61}[A-Za-z0-9])?$", var.api_subdomain))
    error_message = "api_subdomain must be a valid single DNS label such as quizx."
  }
}

# ------------------------------------------------------------------------------
# Accepted but not yet referenced
# ------------------------------------------------------------------------------
# Kept so existing terraform.tfvars files and CI variables keep working
# without "undeclared variable" warnings. None of these change any resource:
# the key pair name comes from local.ec2_key_name and the queue names from
# sqs.tf.
# ------------------------------------------------------------------------------
variable "tf_state_bucket_name" {
  description = "S3 bucket for this stack's state (the backend reads it from backend.hcl instead)"
  type        = string
  default     = null
}

variable "ec2_key_name" {
  description = "Name of the EC2 key pair (the name is derived in locals.tf instead)"
  type        = string
  default     = null
}

variable "quizx_iam_user" {
  description = "Name of the IAM user that runs Terraform"
  type        = string
  default     = null
}

variable "sqs_submit_app_queue_name" {
  description = "Name of the submit app SQS queue (sqs.tf derives the name instead)"
  type        = string
  default     = "submit-app-queue"
}

variable "sqs_moderate_queue_name" {
  description = "Name of the moderate SQS queue (sqs.tf derives the name instead)"
  type        = string
  default     = "moderate-queue"
}
