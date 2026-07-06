output "frontend_url" {
  description = "Public URL of the frontend"
  value       = local.frontend_url
}

output "api_base_url" {
  description = "API base URL (API Gateway endpoint)"
  value       = local.api_base_url
}

output "dynamodb_tables" {
  description = "DynamoDB table names"
  value = {
    users    = aws_dynamodb_table.users.name
    orders   = aws_dynamodb_table.orders.name
    requests = aws_dynamodb_table.requests.name
  }
}

output "frontend_s3_bucket" {
  description = "S3 bucket name for frontend deployment"
  value       = aws_s3_bucket.frontend.bucket
}

output "lambda_function_name" {
  description = "Lambda function name"
  value       = aws_lambda_function.backend.function_name
}
