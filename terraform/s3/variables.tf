variable "website_bucket_name" {
  description = "S3 bucket name for static website hosting."
  type        = string
  default     = "voicecloning-website"
}

variable "website_files_path" {
  description = "The relative path to folder containing website files."
  type        = string
  default     = "../../website/"
}

# Note: "website_bucket_name" will be added in 'locals' as it is not possible to do here
variable "bucket_names" {
  description = "List of S3 bucket names."
  type        = list(string)
  default     = ["voicecloning-inputs", "voicecloning-outputs", "voicecloning-logs"]
}

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