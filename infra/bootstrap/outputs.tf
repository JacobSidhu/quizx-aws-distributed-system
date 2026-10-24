# ------------------------------------------------------------------------------
# Outputs
# ------------------------------------------------------------------------------
# Role ARNs read by the main infrastructure stack (infra/terraform) through
# terraform_remote_state when it creates the EKS cluster and node group.
# ------------------------------------------------------------------------------
output "eks_cluster_role_arn" {
  description = "ARN of the IAM role assumed by the EKS control plane"
  value       = aws_iam_role.eks_cluster.arn
}

output "eks_node_role_arn" {
  description = "ARN of the IAM role assumed by EKS worker nodes"
  value       = aws_iam_role.eks_node.arn
}
