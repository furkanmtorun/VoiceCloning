terraform {
  required_providers {
    aws = {
      source = "hashicorp/aws"
    }
  }

  # the values must be hard-coded
  backend "s3" {
    bucket         = "fmt-project-tf-backend"
    key            = "terraform_iam.tfstate"
    region         = "eu-central-1"
    dynamodb_table = "fmt-project-tf-lock-table"
    encrypt        = true
  }
}

provider "aws" {
  region = var.region
}