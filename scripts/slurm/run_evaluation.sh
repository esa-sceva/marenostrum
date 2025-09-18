#!/bin/bash

# Script for running Llama 3.3 70B Evaluation with vLLM server + filtering_low_grades
# Simple approach: start vLLM server, then run filtering evaluation

echo "Starting Qwen2.5 72B Evaluation with vLLM..."

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
export HF_HOME="/gpfs/projects/<project_id>/myfolder/qwen_72B"
export TRANSFORMERS_OFFLINE=1
export HF_HUB_OFFLINE=1

# Disable OpenAI Harmony features that cause download issues
export VLLM_DISABLE_HARMONY=1
export OPENAI_HARMONY_DISABLE=1

echo "Environment setup:"
echo "- HF_HOME: $HF_HOME" 
echo "- OFFLINE MODE: Enabled"
echo "- GPU: $(nvidia-smi --query-gpu=name --format=csv,noheader | head -1)"

# Use parameters from environment (loaded from config in submit script)
echo "Job parameters:"
echo "- Model: $MODEL_NAME"
echo "- Dataset: $DATASET_PATH"
echo "- Results: $RESULTS_PATH"
echo "- Output: $OUTPUT_PATH"
echo "- Workers: $NUM_WORKERS"
echo "- Threshold: $THRESHOLD"


# Step 1: Start vLLM server in background
echo "Starting vLLM server..."

# Llama 3.3 70B model path
QWEN_MODEL_PATH="/gpfs/projects/<project_id>/myfolder/qwen_72B/models/models--Qwen--Qwen2.5-72B-Instruct/snapshots/495f39366efef23836d0cfae4fbe635880d2be31"

echo "Checking for Qwen2.5 72B model at: $QWEN_MODEL_PATH"

# Verify model exists
if [ ! -f "$QWEN_MODEL_PATH/config.json" ]; then
    echo "ERROR: Qwen2.5 72B model not found!"
    echo "Expected path: $QWEN_MODEL_PATH"
    echo "Searching for alternative model paths in HF cache:"
    find "/gpfs/projects/<project_id>/myfolder/qwen_72B" -name "config.json" -path "*qwen*2.5*72B*" 2>/dev/null | head -5
    exit 1
fi

echo "Found Qwen2.5 72B model at: $QWEN_MODEL_PATH"

# Start vLLM server with tensor parallelism for 70B model (4 GPUs)
nohup python -u -m vllm.entrypoints.openai.api_server \
    --host 0.0.0.0 \
    --model "$QWEN_MODEL_PATH" \
    --disable-log-requests \
    --dtype bfloat16 \
    --tensor-parallel-size 4 \
    --max-model-len 50000 \
    --disable-frontend-multiprocessing \
    --served-model-name qwen2.5-72b \
    --trust-remote-code > "$VLLM_LOG_FILE" 2>&1 &

VLLM_PID=$!
echo "vLLM server started with PID: $VLLM_PID"

# Step 2: Wait for vLLM server to be ready (70B model needs significant time)
echo "Waiting for vLLM server to be ready (Qwen2.5 72B model loading...)..."
for i in {1..900}; do  # Increased to 15 minutes for 70B model
    if curl -s http://localhost:8000/v1/models > /dev/null 2>&1; then
        echo "vLLM server is ready!"
        break
    fi
    if [ $i -eq 900 ]; then
        echo "vLLM server failed to start within 15 minutes"
        echo "Last 20 lines of vLLM server log:"
        tail -20 "$VLLM_LOG_FILE"
        kill $VLLM_PID 2>/dev/null
        exit 1
    fi
    if [ $((i % 30)) -eq 0 ]; then  # Show progress every 30 seconds
        echo "Still loading... ($i/900 seconds) - Qwen2.5 72B model takes significant time"
        echo "Server status: $(ps -p $VLLM_PID > /dev/null 2>&1 && echo 'Running' || echo 'Stopped')"
    fi
    sleep 1
done

# Step 3: Run filtering_low_grades evaluation with all parameters
echo "Starting evaluation with filtering_low_grades..."




# Run the command directly
python -m synthetic_gen.evaluators.filtering_low_grades \
    --dataset_path "$DATASET_PATH" \
    --results_path "$RESULTS_PATH" \
    --output_path "$OUTPUT_PATH" \
    --model_name "$MODEL_NAME" \
    --threshold $THRESHOLD \
    --pertinence_threshold $PERTINENCE_THRESHOLD \
    --contextual_relevance_threshold $CONTEXTUAL_RELEVANCE_THRESHOLD \
    --filter_logic "$FILTER_LOGIC" \
    --temperature $TEMPERATURE \
    --backend "$BACKEND" \
    --num_workers $NUM_WORKERS \
    --n_docs $N_DOCS

EXIT_CODE=$?

# Step 4: Clean up
echo "Cleaning up..."
kill $VLLM_PID 2>/dev/null
wait $VLLM_PID 2>/dev/null

if [ $EXIT_CODE -eq 0 ]; then
    echo "Qwen2.5 72B evaluation completed successfully!"
else
    echo "Qwen2.5 72B evaluation failed with exit code $EXIT_CODE"
fi

echo "vLLM server log saved to: $VLLM_LOG_FILE"
exit $EXIT_CODE
