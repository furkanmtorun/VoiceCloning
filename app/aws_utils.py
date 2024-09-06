"""AWS utilities to be used in entrypoint."""

import os
from typing import Dict

import boto3
import requests

# HARDCODED
BASE_API_URL = "https://l481bschml.execute-api.eu-central-1.amazonaws.com/api"
S3_CLIENT = boto3.client("s3")
S3_BUCKET_NAME_FOR_INPUT: str = "voicecloning-inputs"
S3_BUCKET_NAME_FOR_OUTPUT: str = "voicecloning-outputs"
PAGINATOR = S3_CLIENT.get_paginator("list_objects_v2")


def download_s3_folder(s3_folder, local_dir, bucket_name=S3_BUCKET_NAME_FOR_INPUT):
    """Download a folder from S3 recursively into the local destination directory."""

    for page in PAGINATOR.paginate(Bucket=bucket_name, Prefix=s3_folder):
        if "Contents" not in page:
            print(f"No contents found in S3 folder {s3_folder}")
            return

        for obj in page["Contents"]:
            s3_key = obj["Key"]
            local_file_path = os.path.join(
                local_dir, os.path.relpath(s3_key, s3_folder)
            )
            local_file_dir = os.path.dirname(local_file_path)

            os.makedirs(local_file_dir, exist_ok=True)

            print(f"Downloading {s3_key} to {local_file_path}")
            S3_CLIENT.download_file(bucket_name, s3_key, local_file_path)


def upload_wav_to_s3(local_file_path, s3_key, bucket_name=S3_BUCKET_NAME_FOR_OUTPUT):
    """Upload a .wav file to an S3 bucket.

    :param local_file_path: Local path to the .wav file
    :param bucket_name: Name of the S3 bucket
    :param s3_key: S3 key (path) where the file will be uploaded
    """
    try:
        S3_CLIENT.upload_file(local_file_path, bucket_name, s3_key)
        print(f"File {local_file_path} uploaded to s3://{bucket_name}/{s3_key}")
    except Exception as e:
        print(f"Error uploading file: {e}")


def get_project_details_by_id(project_id: str) -> Dict[str, str]:
    """Return project details dictionary for given project ID."""
    url = f"{BASE_API_URL}/projects/{project_id}"
    response = requests.get(url)
    response.raise_for_status()
    return response.json()
