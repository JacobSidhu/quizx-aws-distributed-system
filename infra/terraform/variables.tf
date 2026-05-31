variable "aws_profile" {
  description = "AWS CLI profile to use for authentication"
  type        = string
  default     = "default"
}

variable "project_name" {
  description = "Name used for tagging and naming AWS resources"
  type        = string
  default     = "quizx"
}

variable "aws_region" {
  description = "AWS region where infrastructure will be deployed"
  type        = string
  default     = "eu-west-2"
}

variable "availability_zone" {
  description = "AWS availability zone for resource deployment"
  type        = string
  default     = "eu-west-2a"
}

variable "vpc_cidr" {
  description = "CIDR block for the VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "vpc_enable_dns_support" {
  description = "Enable DNS support in the VPC"
  type        = bool
  default     = true
}
variable "vpc_enable_dns_hostnames" {
  description = "Enable DNS hostnames in the VPC"
  type        = bool
  default     = true
}

variable "public_route_config" {
  description = "Public route table route configuration"
  type = object({
    cidr_block = string
  })
}

variable "allowed_ssh_cidr" {
  description = "CIDR block allowed to access SSH port"
  type        = string
  default     = null
}

variable "question_app_cidr" {
  description = "CIDR block allowed to access question app port"
  type        = string
  default     = null
}

variable "submit_app_cidr" {
  description = "CIDR block allowed to access submit app port"
  type        = string
  default     = null
}

variable "ssh_port" {
  description = "Port number for the application"
  type        = number
  default     = null
}

variable "submit_app_port" {
  description = "Port number for the application"
  type        = number
  default     = null
}

variable "question_app_port" {
  description = "Port number for the application"
  type        = number
  default     = null
}

variable "public_subnet_cidr" {
  description = "CIDR block for the public subnet"
  type        = string
  default     = "10.0.1.0/24"
}

variable "instance_type" {
  description = "EC2 instance type for the application server"
  type        = string
  default     = "t3.micro"
}

variable "ssh_public_key_path" {
  description = "Path to the SSH public key used for EC2 access"
  type        = string
}

variable "aws_ami_id" {
  description = "AMI ID for the EC2 instance"
  type        = string
  default     = null
}