# ── Lambda Function (container image) ────────────────────────────────────────
# Uses a Docker image stored in ECR that bundles Go binary + Chromium.

resource "aws_lambda_function" "backend" {
  function_name = "${var.app_name}-${var.environment}-backend"
  role          = aws_iam_role.lambda.arn
  package_type  = "Image"

  # Image URI: <ecr_repo_url>:<tag>
  # The tag is set by CI on each deploy (e.g. git SHA or "latest")
  image_uri = "${aws_ecr_repository.backend.repository_url}:${var.lambda_image_tag}"

  memory_size = var.lambda_memory_mb   # 1024 MB minimum for Chromium
  timeout     = var.lambda_timeout_seconds  # 60s — PDF generation can take 15-30s

  architectures = ["x86_64"]

  environment {
    variables = {
      # App config
      APP_ENV            = var.environment
      FRONTEND_URL       = local.frontend_url
      OAUTH_REDIRECT_BASE = local.api_base_url

      # DynamoDB table names
      USERS_TABLE_NAME    = aws_dynamodb_table.users.name
      ORDERS_TABLE_NAME   = aws_dynamodb_table.orders.name
      REQUESTS_TABLE_NAME = aws_dynamodb_table.requests.name

      # SES
      SES_FROM_EMAIL = var.ses_from_email
      AWS_SES_REGION = var.aws_region

      # Secrets — fetched from SSM at startup
      JWT_SECRET          = var.jwt_secret
      RAZORPAY_KEY_ID     = var.razorpay_key_id
      RAZORPAY_KEY_SECRET = var.razorpay_key_secret

      # OAuth (only set if provided)
      GOOGLE_CLIENT_ID     = var.google_client_id
      GOOGLE_CLIENT_SECRET = var.google_client_secret
      GITHUB_CLIENT_ID     = var.github_client_id
      GITHUB_CLIENT_SECRET = var.github_client_secret

      # AI
      GEMINI_API_KEY = var.gemini_api_key

      # Admin allowlist (comma-separated emails) — grants admin without a DB flag
      ADMIN_EMAILS = var.admin_emails

      # Chromium path inside the container
      CHROME_PATH = "/usr/bin/chromium"
    }
  }

  depends_on = [
    aws_iam_role_policy_attachment.lambda_basic,
    null_resource.initial_image_push,
  ]

  lifecycle {
    # image_uri is managed by deploy.sh (aws lambda update-function-code).
    # Ignore it here so terraform apply never rolls back a deploy.
    ignore_changes = [image_uri]
  }
}

# Allow API Gateway to invoke the Lambda
resource "aws_lambda_permission" "apigw" {
  statement_id  = "AllowAPIGatewayInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.backend.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.backend.execution_arn}/*/*"
}

# CloudWatch log group with 30-day retention
resource "aws_cloudwatch_log_group" "lambda" {
  name              = "/aws/lambda/${aws_lambda_function.backend.function_name}"
  retention_in_days = 30
}

locals {
  frontend_url = var.domain_name != "" ? "https://${var.domain_name}" : "https://${aws_cloudfront_distribution.frontend.domain_name}"
  api_base_url = "https://${aws_apigatewayv2_api.backend.id}.execute-api.${var.aws_region}.amazonaws.com"
}
