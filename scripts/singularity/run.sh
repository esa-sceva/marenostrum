#!/bin/bash

CONFIG_PATH="$1"
PIPELINE="$2"
OUTPUT_DIR="$3"

if [[ -z "$CONFIG_PATH" || -z "$PIPELINE" || -z "$OUTPUT_DIR" ]]; then
    echo "Usage: ./run.sh <config_path> <pipeline> <output_dir>"
    exit 1
fi

# Activate the virtual environment
source /mistral-synth-gen/.venv/bin/activate
echo "Starting vLLM server..."

# Start the vLLM server with the provided config
vllm serve --config "$CONFIG_PATH" &
SERVER_PID=$!

MAX_WAIT=300  # in seconds
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

sauceduchef process "$PIPELINE" "$OUTPUT_DIR"

END_TIME=$(date +%s)
ELAPSED_TIME=$((END_TIME - START_TIME))
echo "Total processing time: ${ELAPSED_TIME} seconds"

# Extract input file path from the pipeline YAML
INPUT_FILE=$(grep -E 'input_path:|path:' "$PIPELINE" | head -1 | awk '{print $2}' | tr -d '"')

if [[ -f "$INPUT_FILE" ]]; then
    NUM_DOCS=$(wc -l < "$INPUT_FILE")
    AVG_TIME=$(echo "$ELAPSED_TIME / $NUM_DOCS" | bc -l)
    THROUGHPUT=$(echo "$NUM_DOCS / $ELAPSED_TIME" | bc -l)

    echo "Documents processed: $NUM_DOCS"
    printf "Average time per document: %.3f seconds\n" "$AVG_TIME"
    printf "Processing throughput: %.3f docs/sec\n" "$THROUGHPUT"
else
    echo "Warning: Cannot find input file at path '$INPUT_FILE' — skipping stats."
fi

# Clean up
kill $SERVER_PID

# Clean up
kill $SERVER_PID
