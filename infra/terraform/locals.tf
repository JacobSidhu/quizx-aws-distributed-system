locals {
  name_prefix = var.project_name
  api_fqdn    = var.enable_custom_domain ? "${var.api_subdomain}.${var.domain_name}" : null

  common_tags = {
    Project   = var.project_name
    ManagedBy = "Terraform"
  }
}
