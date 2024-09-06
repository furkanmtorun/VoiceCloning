/* 
This module includes: 
    AWS Batch, Job Queue, Job Definition for Fargate
    CloudWatch Log Group
Notes: 
  - It relies on IAM, Networking and ECR TF modules.
  - Fargate does not support GPU and has limitations of 16 CPUs and 16GB RAM.
  - We do not need to define a separate Batch compute environment for each subnet.
    AWS can manage single compute environment across multiple subnets.
    If we need specialized network or resource configuration per subnet, we can define them separately
*/

data "terraform_remote_state" "networking" {
  backend = "s3"
  config = {
    bucket = "fmt-project-tf-backend"
    key    = "terraform_networking.tfstate"
    region = var.region
  }
}

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

# CloudWatch Utilities
resource "aws_cloudwatch_log_group" "this" {
  name              = "cw-log-group-for-batch-for-voicecloning"
  retention_in_days = 7
}

# AWS Batch
resource "aws_batch_compute_environment" "fargate_compute_environment" {
  compute_environment_name = "aws-batch-fargate-compute-environment"
  type                     = "MANAGED"

  compute_resources {
    type      = "FARGATE"
    max_vcpus = 16 # maximum
    subnets = [
      data.terraform_remote_state.networking.outputs.public_subnet_1a_id,
    ]
    security_group_ids = [data.terraform_remote_state.networking.outputs.security_group_for_batch_id]
  }

  service_role = data.terraform_remote_state.iam.outputs.aws_batch_service_role_arn
}


resource "aws_batch_job_queue" "job_queue" {
  name     = "batch-fargate-voicecloning-job-queue"
  state    = "ENABLED"
  priority = 1

  compute_environment_order {
    order               = 1
    compute_environment = aws_batch_compute_environment.fargate_compute_environment.arn
  }
}


resource "aws_batch_job_definition" "batch_job_definition" {
  name = "aws-batch-job-definition-for-fargate-for-voicecloning"
  deregister_on_new_revision = true
  type = "container"
  platform_capabilities = [
    "FARGATE",
  ]

  container_properties = jsonencode({
    image : "${data.terraform_remote_state.ecr.outputs.ecr_voicecloning_app_repository_url}:latest",
    command : ["python", "entrypoint.py"],
    environment : [
      {
        name : "RUNNING_ENV",
        value : "AWS_BATCH_FARGATE"
      },
      {
        name : "PROJECT_ID",
        value : "demo" # This will be overwritten during job submission. 
      }
    ],

    resourceRequirements = [
      {
        type = "VCPU"
        value = "4"
      },
      {
        type = "MEMORY"
        value = "8192"
      }
    ]
    fargatePlatformConfiguration = {
      platformVersion = "LATEST"
    }
    networkConfiguration = {
      assignPublicIp = "ENABLED"
    }
    logConfiguration = {
      logDriver = "awslogs",
      options = {
        awslogs-group = aws_cloudwatch_log_group.this.name
        awslogs-region = var.region
        awslogs-stream-prefix = "batch-job-def-for-voicecloning-"
      }
    }
    executionRoleArn : data.terraform_remote_state.iam.outputs.aws_batch_execution_role_arn,
    jobRoleArn : data.terraform_remote_state.iam.outputs.aws_batch_execution_role_arn,
  })
}

