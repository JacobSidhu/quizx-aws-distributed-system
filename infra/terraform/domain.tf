# ==============================================================================
# Custom API domain (optional)
# ==============================================================================
# Created only when enable_custom_domain is true. DNS is hosted at GoDaddy,
# not Route 53, so the deployment workflow publishes the records:
#
#   1. Terraform requests an ACM certificate for <api_subdomain>.<domain_name>.
#   2. The workflow publishes the ACM validation record to GoDaddy
#      (output: acm_validation_records).
#   3. Terraform waits for ACM to issue the certificate, then creates the
#      API Gateway custom domain and maps it to the $default stage.
#   4. The workflow points a CNAME at the API Gateway domain target
#      (output: api_gateway_domain_target).
# ==============================================================================
resource "aws_acm_certificate" "api" {
  count = var.enable_custom_domain ? 1 : 0

  domain_name       = local.api_fqdn
  validation_method = "DNS"

  lifecycle {
    create_before_destroy = true
  }

  tags = local.common_tags
}

# Waits for ACM to observe the GoDaddy validation record and issue the
# certificate.
resource "aws_acm_certificate_validation" "api" {
  count = var.enable_custom_domain ? 1 : 0

  certificate_arn = aws_acm_certificate.api[0].arn

  timeouts {
    create = "45m"
  }
}

resource "aws_apigatewayv2_domain_name" "api" {
  count = var.enable_custom_domain ? 1 : 0

  domain_name = local.api_fqdn

  domain_name_configuration {
    certificate_arn = aws_acm_certificate_validation.api[0].certificate_arn
    endpoint_type   = "REGIONAL"
    security_policy = "TLS_1_2"
  }
}

resource "aws_apigatewayv2_api_mapping" "api" {
  count = var.enable_custom_domain ? 1 : 0

  api_id      = aws_apigatewayv2_api.api_gateway.id
  domain_name = aws_apigatewayv2_domain_name.api[0].id
  stage       = aws_apigatewayv2_stage.api_gateway_stage.id
}
