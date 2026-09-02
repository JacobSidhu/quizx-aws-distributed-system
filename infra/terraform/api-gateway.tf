resource "aws_apigatewayv2_api" "api_gateway" {
  name          = "quizx-api-gateway"
  protocol_type = "HTTP"
}

resource "aws_apigatewayv2_stage" "api_gateway_stage" {
  api_id      = aws_apigatewayv2_api.api_gateway.id
  name        = "$default"
  auto_deploy = true
}

resource "aws_apigatewayv2_integration" "api_to_question_app" {
  api_id             = aws_apigatewayv2_api.api_gateway.id
  integration_type   = "HTTP_PROXY"
  integration_method = "GET"
  integration_uri    = "http://${aws_instance.question_app.public_ip}:${var.question_app_port}"
}

resource "aws_apigatewayv2_integration" "api_to_submit_app" {
  api_id             = aws_apigatewayv2_api.api_gateway.id
  integration_type   = "HTTP_PROXY"
  integration_method = "GET"
  integration_uri    = "http://${aws_instance.submit_app.public_ip}:${var.submit_app_port}"
}

resource "aws_apigatewayv2_route" "api_gateway_route_question_app" {
  api_id    = aws_apigatewayv2_api.api_gateway.id
  route_key = "GET /QUESTION"
  target    = "integrations/${aws_apigatewayv2_integration.api_to_question_app.id}"
}

resource "aws_apigatewayv2_route" "api_gateway_route_submit_app" {
  api_id    = aws_apigatewayv2_api.api_gateway.id
  route_key = "GET /SUBMIT"
  target    = "integrations/${aws_apigatewayv2_integration.api_to_submit_app.id}"
}