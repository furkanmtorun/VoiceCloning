#!/bin/bash

# Set AWS profile if necessary
# export AWS_PROFILE=default

# Set the AWS region
export AWS_REGION=eu-central-1

echo "Deleting resources in AWS region: $AWS_REGION"

# Function to delete S3 bucket policy
delete_bucket_policy() {
    bucket=$1
    echo "Deleting bucket policy for $bucket..."
    aws s3api delete-bucket-policy --bucket "$bucket"
}

# Delete S3 buckets
echo "Deleting S3 buckets..."
aws s3 ls | awk '{print $3}' | while read -r bucket; do
    # First, delete the bucket policy to allow deletion
    delete_bucket_policy "$bucket"
    
    # Then, delete the bucket and its contents
    echo "Deleting all contents in $bucket..."
    aws s3 rb "s3://$bucket" --force
done

# Add additional cleanup for other services as needed

echo "Cleanup script completed."
aws s3 ls

#############################
# Cleanup DynamoDB
# Define the table name
TABLE_NAME="fmt-project-tf-lock-table"

# Define the key of the item to delete. Replace ATTRIBUTE_NAME with the actual key attribute name.
KEY_NAME="LockID"
KEY_VALUE="fmt-project-tf-backend/terraform_s3.tfstate-md5"

# AWS CLI command to delete the item
aws dynamodb delete-item \
    --table-name $TABLE_NAME \
    --key "{\"$KEY_NAME\": {\"S\": \"$KEY_VALUE\"}}" \
    --return-values ALL_OLD
