"""API for serving the utilities of VoiceCloning by FastAPI."""

import ast
import uuid
from datetime import datetime
from typing import Dict, List, Optional, Union

import boto3
import requests
from botocore.exceptions import ClientError
from fastapi import FastAPI, File, Form, HTTPException, UploadFile, status
from fastapi.middleware.cors import CORSMiddleware
from mangum import Mangum
from pydantic import BaseModel

_VERSION: str = "0.1.107"
_S3_BUCKET_NAME_FOR_INPUTS: str = "voicecloning-inputs"
BATCH_CLIENT = boto3.client("batch")
BATCH_JOB_QUEUE = "batch-fargate-voicecloning-job-queue"
BATCH_JOB_DEFINITION = "aws-batch-job-definition-for-fargate-for-voicecloning"

app = FastAPI(
    title="VoiceCloning API",
    description="VoiceCloning API",
    version=_VERSION,
    docs_url="/docs",
    # this root_path is referenced by 'aws_api_gateway_deployment.this.stage' to reach 'docs/'
    root_path="/api",
)
# Configure CORS
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],  # Allow requests from any origin
    allow_credentials=False,
    allow_methods=["GET", "POST", "PUT", "DELETE", "OPTIONS"],
    allow_headers=["*"],  # Allow all headers)
)
handler = Mangum(app)  # ASGI adapter for AWS Lambda

# DynamoDB Connection
_TABLE_NAME: str = "projects"
_REGION_NAME: str = "eu-central-1"
db_client = boto3.client("dynamodb", region_name=_REGION_NAME)
s3_client = boto3.client("s3", region_name=_REGION_NAME)


class ProjectBase(BaseModel):
    title: str
    description: Optional[str] = ""  # Description is optional.
    text: str
    quality: str


class Project(ProjectBase):
    # This includes the id, created_at and audio_files, for responses
    id: str
    created_at: str
    # progress: str
    audio_files: List[str]


@app.get("/", response_model=Dict[str, str])
async def root() -> Dict[str, str]:
    return {"api": f"VoiceCloning API | version: {_VERSION}"}


@app.get(path="/health", description="Health check")
def health_check():
    """Health check."""
    response = db_client.describe_table(TableName=_TABLE_NAME)["Table"]["TableStatus"]
    if response == "ACTIVE":
        return {"status": "OK"}
    else:
        return {"status": f"Error: {response}"}


@app.get("/projects", response_model=List[Project])
async def get_projects() -> List[Project]:
    """Returns all projects."""
    response = db_client.scan(TableName=_TABLE_NAME)["Items"]
    projects_db: List[Project] = []
    for item in response:
        project_data = {
            "id": item["id"]["S"],
            "title": item["title"]["S"],
            "description": item["description"]["S"],
            "text": item["text"]["S"],
            "quality": item["quality"]["S"],
            "created_at": item["created_at"]["S"],
            # "progress": item["progress"]["S"],
            # Convert string to list
            "audio_files": ast.literal_eval(item["audio_files"]["S"]),
        }
        projects_db.append(Project(**project_data))

    return projects_db


@app.get("/projects/{project_id}", response_model=Project)
async def get_project(project_id: str) -> Project:
    """Returns the project for provided project ID."""
    response = db_client.query(
        TableName=_TABLE_NAME,
        KeyConditionExpression="id = :project_id",
        ExpressionAttributeValues={":project_id": {"S": project_id}},
    )["Items"]
    if response:
        response = response[0]  # there must be only one project for given ID
        project_data = {
            "id": response["id"]["S"],
            "title": response["title"]["S"],
            "description": response["description"]["S"],
            "text": response["text"]["S"],
            "quality": response["quality"]["S"],
            "created_at": response["created_at"]["S"],
            # "progress": response["progress"]["S"],
            "audio_files": ast.literal_eval(response["audio_files"]["S"]),
        }
        return Project(**project_data)
    raise HTTPException(
        status_code=404, detail=f"Error: Project, ID of {project_id}, not found!"
    )


@app.post("/projects", status_code=status.HTTP_201_CREATED)
async def create_project(
    title: str = Form(...),
    description: str = Form(""),
    text: str = Form(...),
    quality: str = Form(...),
    audio_files: List[UploadFile] = File(...),
) -> Dict[str, Union[int, Project]]:
    """Create a project and submit the task via AWS Batch over Fargate."""
    unique_project_id = uuid.uuid4().hex
    time_now = datetime.now().strftime("%d-%m-%Y_%H:%M:%S")

    # Generate pre-signed URLs and upload to S3
    _process_and_upload_files(audio_files, unique_project_id)

    project_data = {
        "title": title,
        "description": description,
        "text": text,
        "quality": quality,
        "id": unique_project_id,
        "created_at": time_now,
        "audio_files": [audio_file.filename for audio_file in audio_files],
        # NOT IMPLEMENTED YET
        # "progress": "ongoing",  # options: 'ongoing', 'failed', 'ready'
    }

    # Assuming you have a database client named db_client
    response_db = db_client.put_item(
        TableName=_TABLE_NAME,
        Item={**{key: {"S": str(value)} for key, value in project_data.items()}},
    )

    try:
        response_batch = _submit_batch_job(unique_project_id)
    except Exception as e:
        print(f"Failed to submit batch job: {e}")

    return {
        "status_for_db": response_db["ResponseMetadata"]["HTTPStatusCode"],
        "status_for_batch": response_batch["ResponseMetadata"]["HTTPStatusCode"],
        "project": project_data,
    }


def _generate_presigned_url(project_id, audio_file):
    try:
        # Generate pre-signed URL for uploading to S3
        presigned_url = s3_client.generate_presigned_url(
            "put_object",
            Params={
                "Bucket": _S3_BUCKET_NAME_FOR_INPUTS,
                "Key": f"{project_id}/{audio_file.filename}",
            },
            ExpiresIn=3600,  # Set expiration time as 1 hour
        )
    except ClientError as e:
        print(
            f"Failed to generate pre-signed URL for {project_id}/{audio_file.filename}: {e}"
        )

    return presigned_url


def _upload_to_s3(audio_file: File, presigned_url: str):
    filename: str = audio_file.filename
    try:
        # Use requests library to perform PUT request to the pre-signed URL
        with requests.put(presigned_url, data=audio_file.file) as response:
            if response.status_code != 200:
                print(
                    f"Failed to upload {filename} to S3. Status code: {response.status_code}"
                )
            else:
                print(f"{filename} uploaded successfully to S3")
    except Exception as e:
        print(f"Failed to upload {filename} to S3: {e}")


def _process_and_upload_files(audio_files: List[UploadFile], project_id: str) -> None:
    for audio_file in audio_files:
        presigned_url = _generate_presigned_url(project_id, audio_file)
        _upload_to_s3(audio_file=audio_file, presigned_url=presigned_url)


def _submit_batch_job(project_id: str) -> str:
    """Submit a batch job to AWS Batch."""
    response = BATCH_CLIENT.submit_job(
        jobName=f"VoiceCloning-job-{str(uuid.uuid4().hex)}",
        jobQueue=BATCH_JOB_QUEUE,
        jobDefinition=BATCH_JOB_DEFINITION,
        containerOverrides={
            "environment": [{"name": "PROJECT_ID", "value": project_id}]
        },
    )

    print(f"Job submitted. Job ID: {response['jobId']}")
    return response["jobId"]
