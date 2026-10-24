# ------------------------------------------------------------------------------
# Shared values
# ------------------------------------------------------------------------------
locals {
  # Prefix for every named resource, e.g. "quizx-dev". IAM policies, SQS
  # queues, ECR repositories, and EKS clusters are scoped to "<prefix>-*", so
  # this prefix is also the boundary for most IAM permissions.
  name_prefix = "${var.project_name}-${var.environment}"

  # The main infrastructure state shares the bootstrap bucket unless a separate
  # bucket is configured.
  main_state_bucket_name = coalesce(var.tf_main_state_bucket_name, var.tf_bootstrap_state_bucket_name)

  # Standard tags. Applied by the provider's default_tags and matched by the
  # aws:ResourceTag / aws:RequestTag conditions in iam-policy-document.tf.
  common_tags = {
    Project     = var.project_name
    Environment = var.environment
    ManagedBy   = var.managedby
  }

}
