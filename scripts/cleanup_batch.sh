#!/bin/bash

# Ensure AWS CLI is installed
if ! command -v aws &> /dev/null
then
    echo "AWS CLI could not be found. Please install it and configure it."
    exit 1
fi

# Set the AWS region
AWS_REGION="eu-central-1"

echo "Removing AWS Batch job queues and compute environments in region ${AWS_REGION}..."

# Function to wait for compute environments to be disabled
wait_for_compute_environment_disabled() {
    local compute_environment_name=$1
    local status
    echo "Waiting for compute environment $compute_environment_name to be DISABLED..."
    while true; do
        status=$(aws batch describe-compute-environments --compute-environments $compute_environment_name --region $AWS_REGION --query 'computeEnvironments[*].state' --output text)
        if [ "$status" == "DISABLED" ]; then
            echo "Compute environment $compute_environment_name is now DISABLED."
            break
        fi
        sleep 10
    done
}

# Function to disable job queues associated with a compute environment
disable_job_queues_for_compute_environment() {
    local compute_environment_name=$1
    job_queues=$(aws batch describe-job-queues --region $AWS_REGION --query 'jobQueues[*].[jobQueueName,computeEnvironmentOrder]' --output text)
    if [ -n "$job_queues" ]; then
        echo "Disabling Job Queues associated with compute environment $compute_environment_name..."
        while read -r job_queue_name; do
            associated_compute_env=$(echo $job_queues | grep $job_queue_name | awk -F' ' '{print $2}' | grep $compute_environment_name)
            if [ -n "$associated_compute_env" ]; then
                aws batch update-job-queue --job-queue $job_queue_name --state DISABLED --region $AWS_REGION
                echo "Disabled job queue $job_queue_name"
                sleep 5
            fi
        done <<< "$(echo "$job_queues" | awk '{print $1}')"
    else
        echo "No Job Queues found."
    fi
}

# Disable and delete Job Queues
job_queues=$(aws batch describe-job-queues --region $AWS_REGION --query 'jobQueues[*].jobQueueArn' --output text)
if [ -n "$job_queues" ]; then
    echo "Disabling and deleting Job Queues..."
    for job_queue in $job_queues; do
        job_queue_name=$(echo $job_queue | awk -F/ '{print $NF}')
        # Update the job queue to set its state to DISABLED
        aws batch update-job-queue --job-queue $job_queue_name --state DISABLED --region $AWS_REGION
        echo "Disabled job queue $job_queue_name"
        # Wait for the job queue to be disabled before deleting
        sleep 5
        # Delete the job queue
        aws batch delete-job-queue --job-queue $job_queue_name --region $AWS_REGION
        echo "Deleted job queue $job_queue_name"
    done
else
    echo "No Job Queues found."
fi

# Disable and delete Compute Environments
compute_environments=$(aws batch describe-compute-environments --region $AWS_REGION --query 'computeEnvironments[*].computeEnvironmentArn' --output text)
if [ -n "$compute_environments" ]; then
    echo "Disabling and deleting Compute Environments..."
    for compute_environment in $compute_environments; do
        compute_environment_name=$(echo $compute_environment | awk -F/ '{print $NF}')
        # Disable job queues associated with this compute environment
        disable_job_queues_for_compute_environment $compute_environment_name
        # Update the compute environment to set its state to DISABLED
        aws batch update-compute-environment --compute-environment $compute_environment_name --state DISABLED --region $AWS_REGION
        echo "Disabled compute environment $compute_environment_name"
        # Wait for the compute environment to be disabled before deleting
        wait_for_compute_environment_disabled $compute_environment_name
        # Delete the compute environment
        aws batch delete-compute-environment --compute-environment $compute_environment_name --region $AWS_REGION
        echo "Deleted compute environment $compute_environment_name"
    done
else
    echo "No Compute Environments found."
fi

echo -e "\nAll AWS Batch job queues and compute environments have been removed."
