# ECR for Lambda API
resource "aws_ecr_repository" "lambda_api" {
  name                 = "lambda-api"
  image_tag_mutability = "MUTABLE" # more hand for `latest` tag

  image_scanning_configuration {
    scan_on_push = true
  }
}

# ECR for VoiceCloning App
resource "aws_ecr_repository" "voicecloning_app" {
  name                 = "voicecloning_app"
  image_tag_mutability = "MUTABLE" # more hand for `latest` tag

  image_scanning_configuration {
    scan_on_push = true
  }
}
