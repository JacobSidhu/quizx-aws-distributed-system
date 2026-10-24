# ==============================================================================
# IAM policies and attachments
# ==============================================================================
# Each customer-managed policy wraps one document from iam-policy-document.tf.
# Policies are split per AWS service so each one stays small, reviewable, and
# within the IAM policy size limit.
#
# Sections:
#   1. Terraform caller        - state access and permission to assume the role
#   2. Terraform execution     - per-service provisioning permissions
#   3. EKS                     - AWS-managed policies for the cluster and nodes
# ==============================================================================

# ------------------------------------------------------------------------------
# 1. Terraform caller
# ------------------------------------------------------------------------------
# The caller needs state access before the AWS provider can assume the
# Terraform execution role. This policy therefore belongs to the IAM user,
# not the execution role.
# ------------------------------------------------------------------------------
resource "aws_iam_policy" "terraform_caller" {
  name        = "${local.name_prefix}-terraform-caller-policy"
  description = "Permissions for the Terraform caller to use S3 state, assume the execution role, and run deployment checks"
  tags        = local.common_tags
  policy      = jsonencode(local.terraform_caller_policy_document)
}

resource "aws_iam_user_policy_attachment" "terraform_caller" {
  user       = var.quizx_iam_user
  policy_arn = aws_iam_policy.terraform_caller.arn
}

# ------------------------------------------------------------------------------
# 2. Terraform execution role policies
# ------------------------------------------------------------------------------
# One policy per AWS service the platform uses. Most are restricted to the
# deployment region and to resources named "<project>-<environment>-*" or
# carrying the project's tags.
# ------------------------------------------------------------------------------

# EC2, VPC, subnets, routing, security groups, and key pairs.
resource "aws_iam_policy" "terraform_execution_ec2" {
  name        = "${local.name_prefix}-terraform-execution-ec2-policy"
  description = "Permissions for Terraform to manage EC2, VPC, networking, security groups, and key pairs"
  tags        = local.common_tags
  policy      = jsonencode(local.terraform_execution_ec2_policy_document)
}

# VPC endpoints.
resource "aws_iam_policy" "terraform_execution_vpcendpoint" {
  name        = "${local.name_prefix}-terraform-execution-vpcendpoint-policy"
  description = "Permissions for Terraform to manage VPC endpoints"
  tags        = local.common_tags
  policy      = jsonencode(local.terraform_execution_vpc_endpoint_policy_document)
}

# Application Load Balancers, target groups, listeners, and rules.
resource "aws_iam_policy" "terraform_execution_elbv2" {
  name        = "${local.name_prefix}-terraform-execution-elbv2-policy"
  description = "Permissions for Terraform to manage Elastic Load Balancing resources"
  tags        = local.common_tags
  policy      = jsonencode(local.terraform_execution_elbv2_policy_document)
}

# API Gateway resources in the deployment region.
resource "aws_iam_policy" "terraform_execution_apigateway" {
  name        = "${local.name_prefix}-terraform-execution-apigateway-policy"
  description = "Permissions for Terraform to manage API Gateway v2 resources"
  tags        = local.common_tags
  policy      = jsonencode(local.terraform_execution_apigateway_policy_document)
}

# ACM certificates for the optional custom domain (tag-scoped).
resource "aws_iam_policy" "terraform_execution_acm" {
  name        = "${local.name_prefix}-terraform-execution-acm-policy"
  description = "Permissions for Terraform to manage and validate ACM certificates"
  tags        = local.common_tags
  policy      = jsonencode(local.terraform_execution_acm_policy_document)
}

# First-use creation of the ELB and API Gateway service-linked roles.
resource "aws_iam_policy" "terraform_execution_service_linked_roles" {
  name        = "${local.name_prefix}-terraform-execution-service-linked-roles-policy"
  description = "Allow first-use creation of the ELB and API Gateway service-linked roles"
  tags        = local.common_tags
  policy      = jsonencode(local.terraform_execution_service_linked_roles_policy_document)
}

# SQS queues for submitted and moderated questions (name- and tag-scoped).
resource "aws_iam_policy" "terraform_execution_sqs" {
  name        = "${local.name_prefix}-terraform-execution-sqs-policy"
  description = "Permissions for Terraform to manage project SQS queues"
  tags        = local.common_tags
  policy      = jsonencode(local.terraform_execution_sqs_policy_document)

}

# RDS instances, subnet groups, and snapshots.
resource "aws_iam_policy" "terraform_execution_rds" {
  name        = "${local.name_prefix}-terraform-execution-rds-policy"
  description = "Permissions for Terraform to manage QuizX RDS resources"
  tags        = local.common_tags

  policy = jsonencode(local.terraform_execution_rds_policy_document)
}

# First-use creation of the RDS service-linked role.
resource "aws_iam_policy" "terraform_execution_rds_service_linked_role" {
  name        = "${local.name_prefix}-terraform-execution-rds-service-linked-role-policy"
  description = "Allow first-use creation of the RDS service-linked role"
  tags        = local.common_tags
  policy      = jsonencode(local.terraform_execution_rds_service_linked_role_policy_document)
}

# EKS clusters and node groups, plus passing the bootstrap EKS roles.
resource "aws_iam_policy" "terraform_execution_eks" {
  name        = "${local.name_prefix}-terraform-execution-eks-policy"
  description = "Permissions for Terraform to manage EKS clusters and node groups"
  tags        = local.common_tags

  policy = jsonencode(local.terraform_execution_eks_policy_document)
}

# ECR repositories for the service images (name-scoped).
resource "aws_iam_policy" "terraform_execution_ecr" {
  name        = "${local.name_prefix}-terraform-execution-ecr-policy"
  description = "Permissions for Terraform to manage QuizX ECR repositories"
  policy      = jsonencode(local.terraform_execution_ecr_policy_document)
  tags        = local.common_tags
}

# Attaches every execution policy above to the Terraform execution role.
resource "aws_iam_role_policy_attachment" "terraform_execution" {
  for_each = {
    ec2                  = aws_iam_policy.terraform_execution_ec2.arn
    elbv2                = aws_iam_policy.terraform_execution_elbv2.arn
    apigateway           = aws_iam_policy.terraform_execution_apigateway.arn
    acm                  = aws_iam_policy.terraform_execution_acm.arn
    service_linked_roles = aws_iam_policy.terraform_execution_service_linked_roles.arn
    sqs                  = aws_iam_policy.terraform_execution_sqs.arn
    rds                  = aws_iam_policy.terraform_execution_rds.arn
    rds_service_role     = aws_iam_policy.terraform_execution_rds_service_linked_role.arn
    eks                  = aws_iam_policy.terraform_execution_eks.arn
    vpc_endpoint         = aws_iam_policy.terraform_execution_vpcendpoint.arn
    ecr                  = aws_iam_policy.terraform_execution_ecr.arn
  }

  role       = aws_iam_role.terraform_execution.name
  policy_arn = each.value
}

# ------------------------------------------------------------------------------
# 3. EKS
# ------------------------------------------------------------------------------
# AWS-managed policies required by the EKS control plane and worker nodes.
# Nodes get pull-only ECR access; they cannot push images.
# ------------------------------------------------------------------------------
resource "aws_iam_role_policy_attachment" "eks_cluster" {
  role       = aws_iam_role.eks_cluster.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
}

resource "aws_iam_role_policy_attachment" "eks_nodes_worker" {
  role       = aws_iam_role.eks_node.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
}

resource "aws_iam_role_policy_attachment" "eks_nodes_CNI" {
  role       = aws_iam_role.eks_node.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
}

resource "aws_iam_role_policy_attachment" "eks_nodes_ecr" {
  role       = aws_iam_role.eks_node.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryPullOnly"
}

# ------------------------------------------------------------------------------
# State refactoring
# ------------------------------------------------------------------------------
# Records resource renames so Terraform tracks them as the same objects in
# state instead of planning a destroy and a separate create.
# ------------------------------------------------------------------------------
moved {
  from = aws_iam_policy.eks_cluster_policy
  to   = aws_iam_policy.terraform_execution_eks
}

moved {
  from = aws_iam_policy.rdb_service_link
  to   = aws_iam_policy.terraform_execution_rds_service_linked_role
}
