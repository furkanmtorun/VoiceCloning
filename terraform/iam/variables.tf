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
