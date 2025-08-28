#!/bin/bash

CONFIG_PATH="$1"
PIPELINE="$2"
OUTPUT_DIR="$3"
CHECKPOINT_ID="$4"
MAX_SAMPLES="$5" # Maximum number of samples to generate

if [[ -z "$CONFIG_PATH" || -z "$PIPELINE" || -z "$OUTPUT_DIR" ]]; then
    echo "Usage: ./run.sh <config_path> <pipeline> <output_dir>"
    exit 1
fi

# Activate the virtual environment
source /mistral-synth-gen/.venv/bin/activate
echo "Starting vLLM server..."


# Monitor number of samples if MAX_SAMPLES is set
monitor_samples() {
    local count=0
    local interval=20  # seconds between checks

    echo "Monitoring samples in $OUTPUT_DIR (limit: $MAX_SAMPLES)..."

    while true; do
        if [[ -n "$MAX_SAMPLES" ]]; then
            # Count number of lines in all .jsonl files (adjust this if format is different)
            count=$(find "$OUTPUT_DIR" -type f -name '*.jsonl' -exec cat {} + | wc -l)
            echo "Generated samples: $count"

            if (( count >= MAX_SAMPLES )); then
                echo "Reached max samples ($MAX_SAMPLES). Stopping generation."
                pkill -f "secretsauce"
                break
            fi
        fi
        sleep "$interval"
    done
}

# Start monitoring in background
monitor_samples &
MONITOR_PID=$!




# Check if secretsauce is installed
if ! command -v secretsauce &> /dev/null; then
    echo "secretsauce command not found. Please install it first."
    exit 1
fi


# Start the vLLM server with the provided config
vllm serve --config "$CONFIG_PATH" &
SERVER_PID=$!

MAX_WAIT=600  # in seconds
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

kill "$MONITOR_PID" 2>/dev/null
