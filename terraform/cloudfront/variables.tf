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

variable "website_bucket_name" {
  description = "S3 bucket name for static website hosting."
  type        = string
  default     = "voicecloning-website"
}