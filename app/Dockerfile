# Use a lightweight Python 3.10 base image
# Note: "alpine" version is quite painful
FROM python:3.10-slim

# Set working directory
WORKDIR /app

# Copy all codes and large model files to the designated directory
# Note: The layers are ordered from least updated to most frequently updated.
COPY model_files model_files
COPY tortoise tortoise
COPY __init__.py .

# Install dependencies separately to leverage Docker cache
COPY pip_freeze.txt .
RUN pip install --no-cache-dir -r pip_freeze.txt

COPY aws_utils.py .
COPY entrypoint.py .

# Command to run your application
CMD ["python", "entrypoint.py"]
