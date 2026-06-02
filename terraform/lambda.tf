# Placeholder zip — used only on first `terraform apply`.
# After that, lifecycle.ignore_changes prevents Terraform from overwriting
# code deployed by the GitHub Actions deploy workflow.
data "archive_file" "placeholder" {
  type        = "zip"
  output_path = "${path.module}/.placeholder.zip"

  source {
    # Minimal shell bootstrap — Lambda will error until real binary is deployed.
    content  = "#!/bin/sh\necho '{\"statusCode\":503,\"body\":\"not deployed yet\"}'"
    filename = "bootstrap"
  }
}

resource "aws_lambda_function" "api" {
  function_name = "cvfit-api-${var.environment}"
  role          = aws_iam_role.lambda.arn

  filename         = data.archive_file.placeholder.output_path
  source_code_hash = data.archive_file.placeholder.output_base64sha256

  handler       = "bootstrap"
  runtime       = "provided.al2023"
  architectures = ["arm64"]

  memory_size = var.lambda_memory_mb
  timeout     = var.lambda_timeout_sec

  environment {
    variables = {
      ENVIRONMENT          = var.environment
      REGION               = var.aws_region
      DYNAMODB_TABLE_NAME  = aws_dynamodb_table.resumes.name
      S3_BUCKET            = aws_s3_bucket.resume_pdfs.id
      RESUME_OUTPUT_BUCKET = aws_s3_bucket.resume_pdfs.id
    }
  }

  lifecycle {
    # Code is managed by the deploy workflow — Terraform only manages config.
    ignore_changes = [filename, source_code_hash]
  }

  depends_on = [aws_iam_role_policy_attachment.lambda_basic_execution]
}

resource "aws_cloudwatch_log_group" "api" {
  name              = "/aws/lambda/${aws_lambda_function.api.function_name}"
  retention_in_days = 30
}
