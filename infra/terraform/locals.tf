# ==============================================================================
# Shared local values
# ==============================================================================
locals {
  # "<project>-<environment>" prefix for every resource name, for example
  # "quizx-dev". The bootstrap IAM policies scope permissions to this prefix.
  name_prefix = "${var.project_name}-${var.environment}"

  ec2_key_name = "${local.name_prefix}-ec2-key"

  # Fully qualified API hostname, only when the custom domain is enabled.
  api_fqdn = var.enable_custom_domain ? "${var.api_subdomain}.${var.domain_name}" : null

  # Standard tags, applied to every resource through the provider's
  # default_tags. ManagedBy uses the managedby variable.
  common_tags = {
    Project     = var.project_name
    Environment = var.environment
    ManagedBy   = var.managedby
  }
}
