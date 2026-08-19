output "lambda_function_name" {
  description = "Name of the deployed Lambda function"
  value       = aws_lambda_function.app.function_name
}

output "lambda_function_arn" {
  description = "ARN of the deployed Lambda function"
  value       = aws_lambda_function.app.arn
}

output "log_group_name" {
  description = "CloudWatch Log Group for the Lambda function"
  value       = aws_cloudwatch_log_group.lambda_logs.name
}
