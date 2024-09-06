output "lambda_api_role_arn" {
  value = aws_iam_role.lambda_api_role.arn
}

output "api_gateway_logs_role_arn" {
  value = aws_iam_role.api_gateway_logs_role.arn
}

output "aws_batch_service_role_arn" {
  value = aws_iam_role.batch_service_role.arn
}

output "aws_batch_execution_role_arn" {
  value = aws_iam_role.batch_execution_role.arn
}