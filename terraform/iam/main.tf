/*
Notes:
 - Resource ARN pattern is: "arn:aws:SERVICE:REGION:ACCOUNT_ID:TYPE/RESOURCE_ID"
 - IAM needs for Batch and their scopes:
  - Batch Service Role: Used by AWS Batch to manage and operate the Batch service (e.g., job queues, scheduling).
  - Batch Execution Role: Used by AWS Batch to execute and manage tasks related to job execution, like pulling Docker images from ECR.
  - Job Role (Execution Role): Used by the Fargate job itself to access necessary AWS resources during its execution, 
                            such as pulling files from S3, DynamoDB access.
*/


locals {
  projects_table_name        = "projects"
  bucket_name_for_inputs     = "voicecloning-inputs"
  bucket_name_for_outputs    = "voicecloning-outputs"
  cloudwatch_policy_name     = "arn:aws:iam::aws:policy/service-role/AmazonAPIGatewayPushToCloudWatchLogs"
  batch_service_policy_arn   = "arn:aws:iam::aws:policy/service-role/AWSBatchServiceRole"
  batch_execution_policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

#########################
####### POLICIES ########
#########################

resource "aws_iam_policy" "logs_policy" {
  name = "logs-policy"
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "Logging"
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents",
          "logs:DescribeLogGroups",
          "logs:DescribeLogStreams"
        ]
        Resource = "arn:aws:logs:${var.region}:*:*"
      }
    ]
  })
}

resource "aws_iam_policy" "lambda_kms_policy" {
  name        = "LambdaKMSPolicy"
  description = "Policy to allow Lambda to decrypt using a specific KMS key"
  
  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Action = ["kms:Decrypt", "kms:Encrypt", "kms:DescribeKey",],
        Resource = "*"
      }
    ]
  })
}

resource "aws_iam_policy" "s3_input_access_policy" {
  name = "s3_input_access_policy"
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "LambdaS3PutObject"
        Effect = "Allow"
        Action = [
          "s3:PutObject",
          "s3:ListBucket",
          "s3:GetBucketLocation",
          "s3:PutObjectVersion",
          "s3:GetObject",
          "s3:GetObjectVersion"
        ]
        Resource = [
          "arn:aws:s3:::${local.bucket_name_for_inputs}",
          "arn:aws:s3:::${local.bucket_name_for_inputs}/*"
        ]
      }
    ]
  })
}

resource "aws_iam_policy" "s3_output_access_policy" {
  name = "s3_output_access_policy"
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "LambdaS3PutObject"
        Effect = "Allow"
        Action = [
          "s3:PutObject",
          "s3:ListBucket",
          "s3:GetBucketLocation",
          "s3:PutObjectVersion",
          "s3:GetObject",
          "s3:GetObjectVersion"
        ]
        Resource = [
          "arn:aws:s3:::${local.bucket_name_for_outputs}",
          "arn:aws:s3:::${local.bucket_name_for_outputs}/*"
        ]
      }
    ]
  })
}


resource "aws_iam_policy" "lambda_dynamodb_policy" {
  name = "lambda-api-policy_for_dynamodb_operations"
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "LambdaDynamoDbOperations"
        Effect = "Allow"
        Action = [
          "dynamodb:GetItem",
          "dynamodb:PutItem",
          "dynamodb:UpdateItem",
          "dynamodb:DeleteItem",
          "dynamodb:Query",
          "dynamodb:Scan",
          "dynamodb:DescribeTable"
        ]
        Resource = "arn:aws:dynamodb:${var.region}:*:table/${local.projects_table_name}"
      }
    ]
  })
}

resource "aws_iam_policy" "lambda_api_gateway_invoke_policy" {
  name        = "APIGatewayInvokePolicy"
  description = "Policy to allow invocation of API Gateway resources"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect    = "Allow"
        Action    = "execute-api:Invoke"
        Resource  = "*" # "arn:aws:execute-api:${var.region}:*:*"
      }
    ]
  })
}

resource "aws_iam_policy" "ecr_pull_policy" {
  name = "ecr-pull-policy"
  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Sid    = "ECRImagePullAccess",
        Effect = "Allow",
        Action = "*",
        Resource = "arn:aws:ecr:${var.region}:*:repository/*"
      }
    ]
  })
}



#########################
######### ROLES #########
#########################

resource "aws_iam_role" "lambda_api_role" {
  name = "role-for-lambda-api"
  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Sid    = "BasicLambdaPolicyForLambdaAPI",
        Effect = "Allow",
        Principal = {
          Service = "lambda.amazonaws.com"
        },
        Action = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role" "api_gateway_logs_role" {
  name = "role-for-api-gateway-logs"
  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Effect = "Allow",
      Principal = {
        Service = "apigateway.amazonaws.com"
      },
      Action = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role" "batch_service_role" {
  name = "aws-batch-service-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Principal = {
          Service = "batch.amazonaws.com"
        },
        Action = "sts:AssumeRole"
      }
    ]
  })
}

resource "aws_iam_role" "batch_execution_role" {
  name = "batch-execution-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Principal = {
          Service = "ecs-tasks.amazonaws.com"
        },
        Action = "sts:AssumeRole"
      }
    ]
  })
}


#########################
###### Attachments ######
#########################

resource "aws_iam_role_policy_attachment" "lambda_policy_attachments" {
  for_each = {
    for id, policy_arn in [aws_iam_policy.logs_policy.arn, aws_iam_policy.lambda_kms_policy.arn, aws_iam_policy.s3_input_access_policy.arn, aws_iam_policy.lambda_dynamodb_policy.arn] : id => policy_arn
  }
  role       = aws_iam_role.lambda_api_role.name
  policy_arn = each.value
}


resource "aws_iam_role_policy_attachment" "lambda_policy_attachments_for_api_gateways" {
  for_each = {
    for id, policy_arn in [aws_iam_policy.logs_policy.arn, local.cloudwatch_policy_name] : id => policy_arn
  }
  role       = aws_iam_role.api_gateway_logs_role.name
  policy_arn = each.value
}

# Attach batch.amazon.com Service policy and our CloudWatch policy to the Batch Service role
resource "aws_iam_role_policy_attachment" "aws_own_service_policy_attachment_for_batch_service_role" {
  for_each = { for id, policy_arn in [local.batch_service_policy_arn, aws_iam_policy.logs_policy.arn, aws_iam_policy.ecr_pull_policy.arn] : id => policy_arn }
  role       = aws_iam_role.batch_service_role.name
  policy_arn = each.value
}

# Attach necessary policies for Batch and Job Execution Roles (used same manner for simplicity)
resource "aws_iam_role_policy_attachment" "policy_attach_for_batch_and_job_execution_role" {
  for_each = {
    for id, policy_arn in [local.batch_execution_policy_arn, aws_iam_policy.ecr_pull_policy.arn, aws_iam_policy.s3_input_access_policy.arn, aws_iam_policy.s3_output_access_policy.arn, aws_iam_policy.logs_policy.arn] : id => policy_arn
  }
  role       = aws_iam_role.batch_execution_role.name
  policy_arn = each.value
}