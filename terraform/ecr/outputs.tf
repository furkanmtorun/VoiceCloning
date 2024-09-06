# ECR repo url for Lambda API
output "ecr_lambda_api_repository_url" {
  value = aws_ecr_repository.lambda_api.repository_url
}

# ECR repo url for VoiceCloning app
output "ecr_voicecloning_app_repository_url" {
  value = aws_ecr_repository.voicecloning_app.repository_url
}