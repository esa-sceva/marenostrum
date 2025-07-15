#!/bin/bash
# dataset_upload.sh - Script to download dataset and upload via SCP

# Stop on errors
set -e

# Get arguments with defaults
DATASET_NAME=${1:-"default_dataset"}
SPLIT=${2:-"train"}

# Display header
echo "==============================================="
echo "Dataset Uploader"
echo "Dataset: $DATASET_NAME"
echo "Split: $SPLIT"
echo "==============================================="

# Load environment variables from .env file if it exists
if [ -f .env ]; then
    echo "Loading environment variables from .env file"
    export $(grep -v '^#' .env | xargs)
else
    echo "No .env file found. Make sure environment variables are set."
fi

# Check required environment variables
if [ -z "$BSC_USER" ] || [ -z "$BSC_HOST" ] || [ -z "$BSC_DIR" ]; then
    echo "Error: Missing required environment variables"
    echo "Please set BSC_USER, BSC_HOST, and BSC_DIR"
    exit 1
fi

# File paths
JSONL_FILE="/tmp/${DATASET_NAME}_${SPLIT}.jsonl"
REMOTE_PATH="${BSC_USER}@${BSC_HOST}:${BSC_DIR}"

# Make sure remote path ends with slash if it's a directory
if [ -n "$BSC_DIR" ] && [[ ! "$BSC_DIR" == */ ]]; then
    REMOTE_PATH="${REMOTE_PATH}/"
fi

# Step 1: Run Python script to download and prepare dataset
echo "Downloading and preparing dataset..."
python -c "
import json
from datasets import load_dataset

# Load dataset
print(f'Loading dataset \"${DATASET_NAME}\" split \"${SPLIT}\"...')
dataset = load_dataset('${DATASET_NAME}', split='${SPLIT}')
print(f'Loaded dataset with {len(dataset)} rows')
print(dataset)
# Create dirs
import os
os.makedirs(os.path.dirname('${JSONL_FILE}'), exist_ok=True)

# Save as JSONL
with open('${JSONL_FILE}', 'w', encoding='utf-8') as f:
    for item in dataset:
        f.write(json.dumps(item) + '\\n')
print(f'Saved JSONL to ${JSONL_FILE}')
"

# Step 2: Upload using SCP
echo "Uploading to $REMOTE_PATH..."
scp "$JSONL_FILE" "$REMOTE_PATH"

# Check if upload was successful
if [ $? -eq 0 ]; then
    echo "==============================================="
    echo "Upload completed successfully!"
    echo "Local file: $JSONL_FILE"
    echo "Remote destination: $REMOTE_PATH"
    echo "==============================================="
else
    echo "==============================================="
    echo "Upload failed!"
    echo "==============================================="
    exit 1
fi