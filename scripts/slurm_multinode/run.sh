#!/bin/bash

PIPELINE="$1"
OUTPUT_DIR="$2"
CHECKPOINT_ID="$3"

if [[ -z "$PIPELINE" || -z "$OUTPUT_DIR" ]]; then
    echo "Usage: ./run.sh <pipeline> <output_dir>"
    exit 1
fi

echo 'Activating virtual environment...'
source /mistral-synth-gen/.venv/bin/activate



# Check if secretsauce is installed
if ! command -v secretsauce &> /dev/null; then
    echo "secretsauce command not found. Please install it first."
    exit 1
fi


MAX_WAIT=1200  # in seconds
# Wait for the server to be ready using Python, with timeout
echo "Waiting for vLLM server to start (max ${MAX_WAIT}s)..."
SECONDS=0
while ! python -c "import socket; s = socket.socket(); s.settimeout(1); s.connect(('localhost', 8000))" 2>/dev/null; do
  sleep 2
  if [ $SECONDS -ge $MAX_WAIT ]; then
    echo "Timeout: vLLM server did not start within ${MAX_WAIT} seconds."
    kill $SERVER_PID 2>/dev/null
    exit 1
  fi
done
echo "vLLM server is ready!"

# Set environment variables
export OPENAI_API_KEY="EMPTY"
export OPENAI_BASE_URL="http://localhost:8000/v1/"
export NLTK_DATA="/gpfs/projects/<project_id>/myfolder/nltk"  # Optional: adapt to your setup

# Run the sauceduchef pipeline with the given pipeline file and output dir
# Time the pipeline execution
START_TIME=$(date +%s)


# Start GPU monitoring in the background
GPU_LOG_DIR="gpu_logs"
mkdir -p "$GPU_LOG_DIR"

# Use SLURM job ID if available, fallback to PID
LOG_ID="${SLURM_JOB_ID:-$$}"
GPU_LOG_FILE="${GPU_LOG_DIR}/gpu_usage_${LOG_ID}.log"

GPU_LOG_INTERVAL=1200  # seconds


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


if [[ -n "$CHECKPOINT_ID" ]]; then
    secretsauce resume "$PIPELINE" "$OUTPUT_DIR" --checkpoint_id "$CHECKPOINT_ID"
else
    secretsauce process "$PIPELINE" "$OUTPUT_DIR"
fi

END_TIME=$(date +%s)
ELAPSED_TIME=$((END_TIME - START_TIME))
echo "Total processing time: ${ELAPSED_TIME} seconds"

# Extract input file path from the pipeline YAML
INPUT_FILE=$(grep -E 'input_path:|path:' "$PIPELINE" | head -1 | awk '{print $2}' | tr -d '"')

if [[ -f "$INPUT_FILE" ]]; then
    NUM_DOCS=$(wc -l < "$INPUT_FILE")
    AVG_TIME=$(awk "BEGIN {printf \"%.3f\", $ELAPSED_TIME / $NUM_DOCS}")
    THROUGHPUT=$(awk "BEGIN {printf \"%.3f\", $NUM_DOCS / $ELAPSED_TIME}")

    echo "Documents processed: $NUM_DOCS"
    echo "Average time per document: $AVG_TIME seconds"
    echo "Processing throughput: $THROUGHPUT docs/sec"
else
    echo "Warning: Cannot find input file at path '$INPUT_FILE'"
fi


# Clean up
kill $SERVER_PID
# Clean up
kill $GPU_MONITOR_PID
