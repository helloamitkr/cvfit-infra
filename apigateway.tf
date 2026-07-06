# ── API Gateway v2 (HTTP API) → Lambda ───────────────────────────────────────

resource "aws_apigatewayv2_api" "backend" {
  name          = "${var.app_name}-${var.environment}-api"
  protocol_type = "HTTP"
  # No cors_configuration here — CloudFront routes frontend and /api/* from the
  # same domain so there is no cross-origin issue in production.
  # The Go handlers.CORS() middleware covers direct API calls (local dev / Postman).
}

resource "aws_apigatewayv2_integration" "backend" {
  api_id                 = aws_apigatewayv2_api.backend.id
  integration_type       = "AWS_PROXY"
  integration_uri        = aws_lambda_function.backend.invoke_arn
  payload_format_version = "2.0"
  # API Gateway v2 hard cap is 29,000 ms — clamp Lambda's 60 s timeout to that.
  timeout_milliseconds   = 29000
}

# Catch-all route — the Go mux does its own routing internally.
resource "aws_apigatewayv2_route" "catch_all" {
  api_id    = aws_apigatewayv2_api.backend.id
  route_key = "$default"
  target    = "integrations/${aws_apigatewayv2_integration.backend.id}"
}

resource "aws_apigatewayv2_stage" "default" {
  api_id      = aws_apigatewayv2_api.backend.id
  name        = "$default"
  auto_deploy = true

  access_log_settings {
    destination_arn = aws_cloudwatch_log_group.apigw.arn
    format = jsonencode({
      requestId      = "$context.requestId"
      ip             = "$context.identity.sourceIp"
      requestTime    = "$context.requestTime"
      httpMethod     = "$context.httpMethod"
      routeKey       = "$context.routeKey"
      status         = "$context.status"
      responseLength = "$context.responseLength"
      integrationError = "$context.integrationErrorMessage"
    })
  }

  default_route_settings {
    throttling_burst_limit = 100
    throttling_rate_limit  = 50
  }
}

resource "aws_cloudwatch_log_group" "apigw" {
  name              = "/aws/apigateway/${var.app_name}-${var.environment}"
  retention_in_days = 14
}

output "api_gateway_url" {
  description = "API Gateway endpoint — the backend base URL"
  value       = aws_apigatewayv2_api.backend.api_endpoint
}
