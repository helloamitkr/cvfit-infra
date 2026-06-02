output "api_url" {
  description = "API Gateway invoke URL — set as NEXT_PUBLIC_API_URL in the frontend"
  value       = aws_apigatewayv2_stage.default.invoke_url
}

output "lambda_function_name" {
  description = "Lambda function name — used by the deploy workflow"
  value       = aws_lambda_function.api.function_name
}

output "dynamodb_table_name" {
  description = "DynamoDB resumes table name"
  value       = aws_dynamodb_table.resumes.name
}

output "s3_bucket_name" {
  description = "S3 bucket for resume PDFs"
  value       = aws_s3_bucket.resume_pdfs.id
}
