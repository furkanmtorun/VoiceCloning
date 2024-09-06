output "lambda_api_invoke_arn" {
  description = "This will be used by API Gateway."
  value       = aws_lambda_function.api.invoke_arn
}

output "lambda_api_function_name" {
  description = "This will be used by API Gateway."
  value       = aws_lambda_function.api.function_name
}