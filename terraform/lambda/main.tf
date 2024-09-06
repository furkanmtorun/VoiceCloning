# Get the resources from other modules
data "terraform_remote_state" "iam" {
  backend = "s3"
  config = {
    bucket = "fmt-project-tf-backend"
    key    = "terraform_iam.tfstate"
    region = var.region
  }
}

data "terraform_remote_state" "ecr" {
  backend = "s3"
  config = {
    bucket = "fmt-project-tf-backend"
    key    = "terraform_ecr.tfstate"
    region = var.region
  }
}

# Lambda function
resource "aws_lambda_function" "api" {
  function_name = var.lambda_api_name
  role          = data.terraform_remote_state.iam.outputs.lambda_api_role_arn
  image_uri     = "${data.terraform_remote_state.ecr.outputs.ecr_lambda_api_repository_url}:latest"
  package_type  = "Image" # we have Docker image

  # Lambda capacities
  memory_size = 256
  timeout     = 900 # max 15 minutes
  ephemeral_storage {
    size = 10240 # Min 512 MB and the Max 10240 MB
  }

  # Uncomment the next line if you have an M1 processor
  # architectures = [ "arm64" ] 
}
