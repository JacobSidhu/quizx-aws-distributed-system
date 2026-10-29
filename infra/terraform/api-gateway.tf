# ==============================================================================
# API Gateway
# ==============================================================================
# Public entry point for the API. An HTTP API proxies every request through a
# VPC link to the internal ALB, so the ALB itself is never exposed:
#
#   client ──► HTTP API ($default route) ──► VPC link ──► internal ALB
# ==============================================================================
resource "aws_apigatewayv2_api" "api_gateway" {
  name          = "${local.name_prefix}-api"
  protocol_type = "HTTP"
  tags          = local.common_tags
}

resource "aws_apigatewayv2_stage" "api_gateway_stage" {
  api_id      = aws_apigatewayv2_api.api_gateway.id
  name        = "$default"
  auto_deploy = true
  tags        = local.common_tags
}

# ------------------------------------------------------------------------------
# VPC link
# ------------------------------------------------------------------------------
# Network interfaces in the public subnets that let API Gateway reach the
# internal ALB.
# ------------------------------------------------------------------------------
resource "aws_apigatewayv2_vpc_link" "quizx_vpc_link" {
  name = "${local.name_prefix}-vpc-link"
  subnet_ids = [
    aws_subnet.public_1.id,
    aws_subnet.public_2.id
  ]
  security_group_ids = [aws_security_group.vpc_link_sg.id]
  tags               = local.common_tags
}

# ------------------------------------------------------------------------------
# Integration and route
# ------------------------------------------------------------------------------
# A single catch-all route forwards every method and path to the ALB
# listener; path-based routing happens on the ALB (see alb.tf).
# ------------------------------------------------------------------------------
resource "aws_apigatewayv2_integration" "api_to_vpc_link" {
  api_id             = aws_apigatewayv2_api.api_gateway.id
  integration_type   = "HTTP_PROXY"
  integration_method = "ANY"
  integration_uri    = aws_lb_listener.quizx_alb_listener.arn
  connection_type    = "VPC_LINK"
  connection_id      = aws_apigatewayv2_vpc_link.quizx_vpc_link.id
}

resource "aws_apigatewayv2_route" "api_gateway_route" {
  api_id    = aws_apigatewayv2_api.api_gateway.id
  route_key = "$default"
  target    = "integrations/${aws_apigatewayv2_integration.api_to_vpc_link.id}"
}
