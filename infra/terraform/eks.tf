# ==============================================================================
# EKS
# ==============================================================================
# Private EKS cluster for the services moving off EC2. The control plane
# endpoint is private only, and the nodes run in the private subnets with no
# internet route: they reach EC2, ECR, and S3 through the VPC endpoints in
# vpc.tf.
#
# Both IAM roles are created by infra/bootstrap and read through
# terraform_remote_state, so this stack never manages IAM.
# ==============================================================================
resource "aws_eks_cluster" "quizx_cluster" {
  name     = "${local.name_prefix}-eks-cluster"
  role_arn = data.terraform_remote_state.bootstrap.outputs.eks_cluster_role_arn

  vpc_config {
    subnet_ids              = [aws_subnet.private_1.id, aws_subnet.private_2.id]
    endpoint_private_access = true
    endpoint_public_access  = false # API server reachable only from inside the VPC
  }
}

# ------------------------------------------------------------------------------
# Managed node group
# ------------------------------------------------------------------------------
# Waits for the VPC endpoints: without them, nodes in the private subnets
# cannot register with the cluster or pull images, and node group creation
# fails.
# ------------------------------------------------------------------------------
resource "aws_eks_node_group" "quizx_node_group" {
  cluster_name    = aws_eks_cluster.quizx_cluster.name
  node_group_name = "${local.name_prefix}-node"
  node_role_arn   = data.terraform_remote_state.bootstrap.outputs.eks_node_role_arn
  subnet_ids      = [aws_subnet.private_1.id, aws_subnet.private_2.id]
  instance_types  = ["t3.micro"]
  capacity_type   = "ON_DEMAND"

  scaling_config {
    desired_size = 2
    min_size     = 2
    max_size     = 4
  }

  update_config {
    max_unavailable = 1
  }

  tags = local.common_tags

  depends_on = [
    aws_vpc_endpoint.endpoint,
    aws_vpc_endpoint.s3_endpoint
  ]
}
