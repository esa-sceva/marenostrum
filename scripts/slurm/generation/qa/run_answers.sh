#!/bin/bash

# Script for running Answer Generation with vLLM server + LLMAnswerFromQuestions
# Simple approach: start vLLM server, then run answer generation

echo "Starting Answer Generation with vLLM..."

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
export HF_HOME="/gpfs/projects/<project_id>/myfolder/llama_70B"
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
echo "- Questions file: $QUESTIONS_FILE"
echo "- Input source: $INPUT_SOURCE"
echo "- Output destination: $OUTPUT_DESTINATION"
echo "- Results file: $RESULTS_FILE"
echo "- Workers: $NUM_WORKERS"
echo "- Temperature: $TEMPERATURE"

# Step 1: Start vLLM server in background
echo "Starting vLLM server..."

# Llama 3.3 70B model path
LLAMA_MODEL_PATH="/gpfs/projects/<project_id>/myfolder/llama_70B/models/models--meta-llama--Llama-3.3-70B-Instruct/snapshots/6f6073b423013f6a7d4d9f39144961bfbfbc386b"

echo "Checking for Llama 3.3 70B model at: $LLAMA_MODEL_PATH"

# Verify model exists
if [ ! -f "$LLAMA_MODEL_PATH/config.json" ]; then
    echo "ERROR: Llama 3.3 70B model not found!"
    echo "Expected path: $LLAMA_MODEL_PATH"
    echo "Searching for alternative model paths in HF cache:"
    find "/gpfs/projects/<project_id>/myfolder/llama_70B" -name "config.json" -path "*llama*3.3*70B*" 2>/dev/null | head -5
    exit 1
fi

echo "Found Llama 3.3 70B model at: $LLAMA_MODEL_PATH"

# Start vLLM server with tensor parallelism for 70B model (4 GPUs)
nohup python -u -m vllm.entrypoints.openai.api_server \
    --host 0.0.0.0 \
    --model "$LLAMA_MODEL_PATH" \
    --disable-log-requests \
    --dtype bfloat16 \
    --tensor-parallel-size 4 \
    --max-model-len 120000 \
    --disable-frontend-multiprocessing \
    --served-model-name llama3.3-70B \
    --trust-remote-code \
    --gpu-memory-utilization 0.85 \
    --enforce-eager \
    --disable-custom-all-reduce > "$VLLM_LOG_FILE" 2>&1 &

VLLM_PID=$!
echo "vLLM server started with PID: $VLLM_PID"

# Step 2: Wait for vLLM server to be ready (70B model needs significant time)
echo "Waiting for vLLM server to be ready (Llama 3.3 70B model loading...)..."
for i in {1..900}; do  # 15 minutes for 70B model
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
        echo "Still loading... ($i/900 seconds) - 70B model takes significant time"
        echo "Server status: $(ps -p $VLLM_PID > /dev/null 2>&1 && echo 'Running' || echo 'Stopped')"
    fi
    sleep 1
done

# Step 3: Clear Python cache to ensure latest code is used
echo "Clearing Python cache..."
find /satcom-synthetic-data-gen/synthetic_gen -type d -name __pycache__ -exec rm -rf {} + 2>/dev/null || true
find /satcom-synthetic-data-gen/synthetic_gen -type f -name "*.pyc" -delete 2>/dev/null || true

# Verify we have the right file
echo "Verifying LLMAnswerFromQuestions.py file..."
ls -lh /satcom-synthetic-data-gen/synthetic_gen/generators/LLMAnswerFromQuestions.py
echo "First 20 lines of the file:"
head -20 /satcom-synthetic-data-gen/synthetic_gen/generators/LLMAnswerFromQuestions.py
echo "Checking for 'Starting LLM Answer Generator from Questions' in the file:"
grep -n "Starting LLM Answer Generator from Questions" /satcom-synthetic-data-gen/synthetic_gen/generators/LLMAnswerFromQuestions.py || echo "NOT FOUND! File is wrong!"

# Run LLMAnswerFromQuestions with explicit path verification
echo "Starting answer generation with LLMAnswerFromQuestions..."
echo "Python path: $(which python)"
echo "Python version: $(python --version)"
echo "PYTHONPATH: $PYTHONPATH"
echo "Running command:"
echo "python -B -m synthetic_gen.generators.LLMAnswerFromQuestions --questions_file $QUESTIONS_FILE ..."

python -B -m synthetic_gen.generators.LLMAnswerFromQuestions \
    --questions_file "$QUESTIONS_FILE" \
    --input_source "$INPUT_SOURCE" \
    --input_type "$INPUT_TYPE" \
    --output_type "$OUTPUT_TYPE" \
    --model_name "$MODEL_NAME" \
    --temperature "$TEMPERATURE" \
    --backend "$BACKEND" \
    --num_workers "$NUM_WORKERS" \
    --vllm_url "$VLLM_URL" \
    --prompt_path "$PROMPT_PATH" \
    --results_file "$RESULTS_FILE" \
    --n_docs "$N_DOCS" \
    --n_shots "$N_SHOTS" \
    --max_retries "$MAX_RETRIES"

EXIT_CODE=$?

# Step 4: Clean up
echo "Cleaning up..."
kill $VLLM_PID 2>/dev/null
wait $VLLM_PID 2>/dev/null

if [ $EXIT_CODE -eq 0 ]; then
    echo "Answer generation completed successfully!"
    echo "Results saved to: $RESULTS_FILE"
else
    echo "Answer generation failed with exit code $EXIT_CODE"
fi

echo "vLLM server log saved to: $VLLM_LOG_FILE"
exit $EXIT_CODE

