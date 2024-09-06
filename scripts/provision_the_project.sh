#!/bin/bash

# Create TF backend S3 bucket (versioning enabled), referenced in `providers.tf` files
aws s3 mb s3://fmt-project-tf-backend --region eu-central-1
aws s3api put-bucket-versioning --bucket fmt-project-tf-backend --versioning-configuration Status=Enabled

# Create dynamoDB table with a primary (partition) key `LockID` of type string and turn `on` deletion protection
aws dynamodb create-table \
    --table-name fmt-project-tf-lock-table \
    --attribute-definitions \
        AttributeName=LockID,AttributeType=S \
    --key-schema \
        AttributeName=LockID,KeyType=HASH \
    --billing-mode PAY_PER_REQUEST \
    --deletion-protection-enabled

# ----------------------------------------------------------------------

# Go to terraform folder
cd "./terraform"

# Define the subfolders, respectively
folders="networking s3 iam ecr lambda dynamodb api_gateway cloudfront batch"

# Loop through each folder
for folder in $folders; do
  # Change directory to the folder
  cd "$folder" || continue

  # Build Docker image for API
  if [ "$folder" == "lambda" ]; then
    cd ../../api
    export IMAGE_NAME="lambda-api"
    export REGION="eu-central-1"
    export ECR_REPO_URL="851725270120.dkr.ecr.eu-central-1.amazonaws.com/lambda-api"
    aws ecr get-login-password --region ${REGION} | docker login --username AWS --password-stdin ${ECR_REPO_URL}
    docker build -t ${IMAGE_NAME} .
    docker tag "${IMAGE_NAME}:latest" "${ECR_REPO_URL}:latest" && docker push "${ECR_REPO_URL}:latest"
  fi

  # Build Docker image for APP
  if [ "$folder" == "batch" ]; then
    cd ../../app
    export IMAGE_NAME="voicecloning-app"
    export REGION="eu-central-1"
    export ECR_REPO_URL="851725270120.dkr.ecr.eu-central-1.amazonaws.com/voicecloning_app"
    aws ecr get-login-password --region ${REGION} | docker login --username AWS --password-stdin ${ECR_REPO_URL}
    docker build -t ${IMAGE_NAME} .
    docker tag "${IMAGE_NAME}:latest" "${ECR_REPO_URL}:latest" && docker push "${ECR_REPO_URL}:latest"
  fi

  # Run Terraform commands
  sleep 2 # in case AWS handling takes some extra time
  terraform init
  terraform fmt && terraform validate
  terraform plan >> './tf-plan-output.log'
  terraform apply -auto-approve

  # Exit the folder
  cd ..
done

echo "Terraform (auto-approved) commands completed for all folders."