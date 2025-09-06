#!/bin/bash

# Script for running GPT-OSS with vLLM server + LLMGenerator
# Simple approach: start vLLM server, then run LLMGenerator

echo "Starting GPT-OSS QA Generation with vLLM..."

# Activate the virtual environment
VENV_PATH="/satcom-synthetic-data-gen/synthetic_gen/.venv"
if [ -f "$VENV_PATH/bin/activate" ]; then
    echo "Activating virtual environment at: $VENV_PATH"
    source "$VENV_PATH/bin/activate"
else
    echo "WARNING: Virtual environment not found at $VENV_PATH"
fi

echo "Python version: $(python --version 2>&1)"

# Set up Python path
REPO_PATH="/satcom-synthetic-data-gen"
export PYTHONPATH="$REPO_PATH:$PYTHONPATH"

# Set environment for offline mode
export HF_HOME="/gpfs/projects/<project_id>/myfolder/gpt_oss"
export TRANSFORMERS_OFFLINE=1
export HF_HUB_OFFLINE=1

# Disable OpenAI Harmony features that cause download issues
export VLLM_DISABLE_HARMONY=1
export OPENAI_HARMONY_DISABLE=1

echo "Environment setup:"
echo "- HF_HOME: $HF_HOME" 
echo "- OFFLINE MODE: Enabled"
echo "- GPU: $(nvidia-smi --query-gpu=name --format=csv,noheader | head -1)"

# Parameters from config
INPUT_SOURCE="/gpfs/projects/<project_id>/myfolder/data_extracted_cleaned"
INPUT_TYPE="local"
OUTPUT_DESTINATION="/gpfs/projects/<project_id>/myfolder/results"
OUTPUT_TYPE="local"
MODEL_NAME="openai/gpt-oss-20b"
TEMPERATURE="0.1"
N_DOCS="20"
N_SHOTS="2"
BACKEND="vllm"
NUM_WORKERS="2"
VLLM_URL="http://localhost:8000/v1"

echo "Job parameters:"
echo "- Model: $MODEL_NAME"
echo "- Input: $INPUT_SOURCE"
echo "- Output: $OUTPUT_DESTINATION"
echo "- Documents: $N_DOCS"

# Step 1: Start vLLM server in background
echo "🚀 Starting vLLM server..."

# Find the actual path to the GPT-OSS model 
GPT_OSS_BASE="/gpfs/projects/<project_id>/myfolder/gpt_oss"

echo "🔍 Searching for GPT-OSS model in $GPT_OSS_BASE"

# Look for the model in the standard HF cache structure
GPT_OSS_MODEL_PATH=$(find "$GPT_OSS_BASE" -name "config.json" -path "*/models--openai--gpt-oss*" | head -1 | xargs dirname 2>/dev/null)

# If not found in HF format, try direct search
if [ -z "$GPT_OSS_MODEL_PATH" ]; then
    GPT_OSS_MODEL_PATH=$(find "$GPT_OSS_BASE" -name "config.json" | head -1 | xargs dirname 2>/dev/null)
fi

# If still not found, list what's available
if [ -z "$GPT_OSS_MODEL_PATH" ] || [ ! -f "$GPT_OSS_MODEL_PATH/config.json" ]; then
    echo "❌ ERROR: GPT-OSS model not found!"
    echo "Searching for model files in $GPT_OSS_BASE:"
    find "$GPT_OSS_BASE" -name "config.json" 2>/dev/null | head -5
    echo "Available directories:"
    ls -la "$GPT_OSS_BASE/" 2>/dev/null
    if [ -d "$GPT_OSS_BASE/models" ]; then
        echo "Contents of models directory:"
        ls -la "$GPT_OSS_BASE/models/" 2>/dev/null
    fi
    exit 1
fi

echo "✅ Found GPT-OSS model at: $GPT_OSS_MODEL_PATH"

# Try to disable harmony features and use basic server
nohup python -u -m vllm.entrypoints.openai.api_server \
    --host 0.0.0.0 \
    --model "$GPT_OSS_MODEL_PATH" \
    --disable-log-requests \
    --dtype bfloat16 \
    --tensor-parallel-size 1 \
    --max-model-len 8192 \
    --disable-frontend-multiprocessing \
    --served-model-name gpt-oss \
    --trust-remote-code > vllm_server.log 2>&1 &

VLLM_PID=$!
echo "vLLM server started with PID: $VLLM_PID"

# Step 2: Wait for vLLM server to be ready (GPT-OSS 20B needs more time)
echo "⏳ Waiting for vLLM server to be ready (GPT-OSS 20B model loading...)..."
for i in {1..180}; do  # Increased to 3 minutes for large model
    if curl -s http://localhost:8000/v1/models > /dev/null 2>&1; then
        echo "✅ vLLM server is ready!"
        break
    fi
    if [ $i -eq 180 ]; then
        echo "❌ vLLM server failed to start within 3 minutes"
        echo "📄 Last 20 lines of vLLM server log:"
        tail -20 vllm_server.log
        kill $VLLM_PID 2>/dev/null
        exit 1
    fi
    if [ $((i % 15)) -eq 0 ]; then  # Show progress every 15 seconds
        echo "Still loading... ($i/180 seconds) - Large model takes time"
        echo "Server status: $(ps -p $VLLM_PID > /dev/null 2>&1 && echo 'Running' || echo 'Stopped')"
    fi
    sleep 1
done

# Step 3: Run LLMGenerator
echo "🤖 Starting QA generation..."
python -m LLMGenerator \
    --input_source "$INPUT_SOURCE" \
    --input_type "$INPUT_TYPE" \
    --output_destination "$OUTPUT_DESTINATION" \
    --output_type "$OUTPUT_TYPE" \
    --model_name "$MODEL_NAME" \
    --temperature "$TEMPERATURE" \
    --n_docs "$N_DOCS" \
    --n_shots "$N_SHOTS" \
    --backend "$BACKEND" \
    --num_workers "$NUM_WORKERS" \
    --vllm_url "$VLLM_URL"

EXIT_CODE=$?

# Step 4: Clean up
echo "🧹 Cleaning up..."
kill $VLLM_PID 2>/dev/null
wait $VLLM_PID 2>/dev/null

if [ $EXIT_CODE -eq 0 ]; then
    echo "✅ GPT-OSS QA generation completed successfully!"
else
    echo "❌ GPT-OSS QA generation failed with exit code $EXIT_CODE"
fi

echo "📄 vLLM server log saved to: vllm_server.log"
exit $EXIT_CODE
