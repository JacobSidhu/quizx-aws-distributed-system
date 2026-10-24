# ==============================================================================
# IAM roles
# ==============================================================================
# Bootstrap creates the identities that every other stage relies on:
#
#   terraform_execution  - assumed by infra/terraform to provision the platform
#   eks_cluster          - assumed by the EKS control plane
#   eks_node             - assumed by EKS worker nodes (EC2)
#
# Permissions are attached in iam-policies.tf; policy documents live in
# iam-policy-document.tf.
# ==============================================================================

# ------------------------------------------------------------------------------
# Terraform execution role
# ------------------------------------------------------------------------------
# infra/terraform assumes this role to create the platform. It carries only the
# per-service provisioning policies, so the caller's own identity needs nothing
# beyond state access and permission to assume this role.
# ------------------------------------------------------------------------------
resource "aws_iam_role" "terraform_execution" {
  name        = var.terraform_execution_role_name
  description = "Assumed by infra/terraform to provision the QuizX platform"
  tags        = local.common_tags

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          AWS = "arn:aws:iam::${var.aws_account_id}:user/${var.quizx_iam_user}"
        }
      }
    ]
  })
}

# ------------------------------------------------------------------------------
# EKS control plane role
# ------------------------------------------------------------------------------
# Trusted only by the EKS service. Its ARN is exported in outputs.tf.
# ------------------------------------------------------------------------------
resource "aws_iam_role" "eks_cluster" {
  name        = var.eks_cluster_role_name
  description = "Assumed by the QuizX EKS control plane"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = "sts:AssumeRole"
      Principal = {
        Service = "eks.amazonaws.com"
      }
    }]
  })
}

# ------------------------------------------------------------------------------
# EKS worker node role
# ------------------------------------------------------------------------------
# Trusted by EC2 so managed node group instances can join the cluster. Its ARN
# is exported in outputs.tf.
# ------------------------------------------------------------------------------
resource "aws_iam_role" "eks_node" {
  name        = var.eks_node_role_name
  description = "Assumed by QuizX EKS worker nodes"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = "sts:AssumeRole"
      Principal = {
        Service = "ec2.amazonaws.com"
      }
    }]
  })
}
