#!/bin/bash

# Script for running s3_chunk_eval_upload module
# Uses fixed parameters instead of arguments to avoid quoting issues

echo "Starting s3_chunk_eval_upload process..."

# Activate the virtual environment created during container build
VENV_PATH="/satcom-synthetic-data-gen/synthetic_gen/.venv"
if [ -f "$VENV_PATH/bin/activate" ]; then
    echo "Activating virtual environment at: $VENV_PATH"
    source "$VENV_PATH/bin/activate"
    echo "Virtual environment activated"
else
    echo "WARNING: Virtual environment not found at $VENV_PATH"
    echo "Looking for alternative venv locations..."
    find /satcom-synthetic-data-gen -name "activate" -type f 2>/dev/null || echo "No activate script found"
fi

echo "Python version: $(python --version 2>&1)"
echo "Python path: $(which python 2>&1)"
echo "PyTorch check: $(python -c 'import torch; print("PyTorch version:", torch.__version__)' 2>&1 || echo 'PyTorch not found')"

# Fixed parameters from config
INPUT_SOURCE="/gpfs/projects/<project_id>/myfolder/data_extracted"
INPUT_TYPE="local"
PROMPT_TEMPLATE="./evaluators/prompts/ultraRM_prompt.yaml"
OUTPUT_DESTINATION="output"
OUTPUT_TYPE="local"
SCORE_THRESHOLD="-12"
MAX_CHUNK_SIZE="4096"
LOCAL_JSON_PATH="./selected_chunks_scores.json"
LOGS_FOLDER="logs"

# Add the synthetic data gen repo to Python path (we know it's at /satcom-synthetic-data-gen)
echo "Setting up Python path for satcom-synthetic-data-gen..."
REPO_PATH="/satcom-synthetic-data-gen"

if [ -d "$REPO_PATH" ]; then
    echo "Found repo at: $REPO_PATH"
    export PYTHONPATH="$REPO_PATH:$PYTHONPATH"
    
    # Also add the synthetic_gen subdirectory
    if [ -d "$REPO_PATH/synthetic_gen" ]; then
        echo "Adding synthetic_gen to path: $REPO_PATH/synthetic_gen"
        export PYTHONPATH="$REPO_PATH/synthetic_gen:$PYTHONPATH"
    fi
    
    echo "Final PYTHONPATH: $PYTHONPATH"
else
    echo "ERROR: Repository not found at expected path: $REPO_PATH"
    echo "Container contents:"
    ls -la / | head -20
    exit 1
fi

# Check if module is available now
echo "Checking for s3_chunk_eval_upload module..."
python -c "import s3_chunk_eval_upload; print('Module found!')" || {
    echo "ERROR: s3_chunk_eval_upload module not found"
    echo "Python path: $PYTHONPATH"
    echo "Repository contents:"
    ls -la "$REPO_PATH/" 2>/dev/null
    ls -la "$REPO_PATH/synthetic_gen/" 2>/dev/null
    exit 1
}

# Create necessary directories
mkdir -p "$(dirname "$OUTPUT_DESTINATION")"
mkdir -p "$(dirname "$LOCAL_JSON_PATH")"
mkdir -p "$LOGS_FOLDER"

# Set environment variables for NLTK data
export NLTK_DATA="/gpfs/projects/<project_id>/myfolder/nltk_data"
echo "NLTK_DATA set to: $NLTK_DATA"

# Start GPU monitoring in the background
GPU_LOG_DIR="gpu_logs"
mkdir -p "$GPU_LOG_DIR"

# Use SLURM job ID if available, fallback to PID
LOG_ID="${SLURM_JOB_ID:-$$}"
GPU_LOG_FILE="${GPU_LOG_DIR}/gpu_usage_${LOG_ID}.log"

GPU_LOG_INTERVAL=300  # seconds (5 minutes for this shorter job)

echo "Starting GPU monitoring every $GPU_LOG_INTERVAL seconds..."
(
    while true; do
        TIMESTAMP=$(date '+%Y-%m-%d %H:%M:%S')
        echo "[$TIMESTAMP] --- nvidia-smi ---" >> "$GPU_LOG_FILE"
        nvidia-smi >> "$GPU_LOG_FILE" 2>&1
        echo "" >> "$GPU_LOG_FILE"
        sleep "$GPU_LOG_INTERVAL"
    done
) &
GPU_MONITOR_PID=$!

# Time the execution
START_TIME=$(date +%s)

echo "Running s3_chunk_eval_upload with parameters:"
echo "- Input source: $INPUT_SOURCE"
echo "- Input type: $INPUT_TYPE"
echo "- Prompt template: $PROMPT_TEMPLATE"
echo "- Output destination: $OUTPUT_DESTINATION"
echo "- Output type: $OUTPUT_TYPE"
echo "- Score threshold: $SCORE_THRESHOLD"
echo "- Max chunk size: $MAX_CHUNK_SIZE"
echo "- Local JSON path: $LOCAL_JSON_PATH"
echo "- Logs folder: $LOGS_FOLDER"

# Run the s3_chunk_eval_upload module
python -m s3_chunk_eval_upload \
  --input_source "$INPUT_SOURCE" \
  --input_type "$INPUT_TYPE" \
  --prompt_template "$PROMPT_TEMPLATE" \
  --output_destination "$OUTPUT_DESTINATION" \
  --output_type "$OUTPUT_TYPE" \
  --score_threshold "$SCORE_THRESHOLD" \
  --max_chunk_size "$MAX_CHUNK_SIZE" \
  --local_json_path "$LOCAL_JSON_PATH" \
  --logs_folder "$LOGS_FOLDER"

EXIT_CODE=$?

END_TIME=$(date +%s)
ELAPSED_TIME=$((END_TIME - START_TIME))
echo "Total processing time: ${ELAPSED_TIME} seconds"

# Clean up GPU monitoring
kill $GPU_MONITOR_PID 2>/dev/null

if [ $EXIT_CODE -eq 0 ]; then
    echo "s3_chunk_eval_upload completed successfully!"
else
    echo "s3_chunk_eval_upload failed with exit code $EXIT_CODE"
fi

exit $EXIT_CODE
