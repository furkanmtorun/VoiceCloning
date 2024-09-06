variable "region" {
  description = "The AWS region."
  default     = "eu-central-1"
  type        = string
}

variable "environment" {
  description = "The environment of the project."
  default     = "PROD"
  type        = string
}

variable "lambda_api_name" {
  description = "The name of the lambda function for API."
  type        = string
  default     = "lambda-api"
}