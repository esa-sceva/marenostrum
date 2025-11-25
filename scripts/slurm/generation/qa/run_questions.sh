#!/bin/bash

# Script for running Question Generation with vLLM server
# Start vLLM server, then run LLMQuestionGenerator

echo "Starting Question Generation with vLLM..."

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

# GPU cleanup and verification
echo "=== GPU Status Check ==="
echo "Available GPUs:"
nvidia-smi --query-gpu=index,name,memory.used,memory.total,utilization.gpu --format=csv,noheader,nounits

echo "Checking for existing vLLM processes..."
if pgrep -f "vllm.entrypoints.openai.api_server" > /dev/null; then
    echo "WARNING: Found existing vLLM processes, killing them..."
    pkill -f "vllm.entrypoints.openai.api_server"
    sleep 5
fi

echo "Clearing GPU memory..."
nvidia-smi --gpu-reset || echo "GPU reset not available, continuing..."

echo "Final GPU status:"
nvidia-smi --query-gpu=index,name,memory.used,memory.total,utilization.gpu --format=csv,noheader,nounits

# Use parameters from environment (loaded from config in submit script)
echo "Job parameters:"
echo "- Model: $MODEL_NAME"
echo "- Input source: $INPUT_SOURCE"
echo "- Input type: $INPUT_TYPE"
echo "- Output destination: $OUTPUT_DESTINATION"
echo "- Output type: $OUTPUT_TYPE"
echo "- Results file: $RESULTS_FILE"
echo "- Workers: $NUM_WORKERS"
echo "- Prompt path: $PROMPT_PATH"
echo "- Multi-prompt mode: $MULTI_PROMPT_MODE"

# Step 1: Start vLLM server in background
echo "Starting vLLM server..."

# LLama3.3 70B model path
LLAMA_MODEL_PATH="/gpfs/projects/<project_id>/myfolder/llama_70B/models/models--meta-llama--Llama-3.3-70B-Instruct/snapshots/6f6073b423013f6a7d4d9f39144961bfbfbc386b"

echo "Checking for LLama3.3 70B model at: $LLAMA_MODEL_PATH"

# Verify model exists
if [ ! -f "$LLAMA_MODEL_PATH/config.json" ]; then
    echo "ERROR: LLama3.3 70B model not found!"
    echo "Expected path: $LLAMA_MODEL_PATH"
    echo "Searching for alternative model paths in HF cache:"
    find "/gpfs/projects/<project_id>/myfolder/llama_70B" -name "config.json" -path "*llama*3.3*70B*" 2>/dev/null | head -5
    exit 1
fi

echo "Found LLama3.3 70B model at: $LLAMA_MODEL_PATH"

# Set additional environment variables for GPU stability
export CUDA_VISIBLE_DEVICES=0,1,2,3
export CUDA_LAUNCH_BLOCKING=1
export NCCL_DEBUG=INFO

echo "Starting vLLM server with GPU devices: $CUDA_VISIBLE_DEVICES"

# Start vLLM server with tensor parallelism for 70B model (4 GPUs) - using working config
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

# Check if the process started successfully
sleep 5
if ! ps -p $VLLM_PID > /dev/null 2>&1; then
    echo "ERROR: vLLM server process died immediately after startup"
    echo "Last 50 lines of vLLM server log:"
    tail -50 "$VLLM_LOG_FILE"
    exit 1
fi

# Step 2: Wait for vLLM server to be ready (72B model needs significant time)
echo "Waiting for vLLM server to be ready (LLama3.3 70B model loading...)..."
for i in {1..900}; do  # 15 minutes for 72B model
    if curl -s http://localhost:8000/v1/models > /dev/null 2>&1; then
        echo "vLLM server is ready!"
        break
    fi
    
    # Check if process is still running
    if ! ps -p $VLLM_PID > /dev/null 2>&1; then
        echo "ERROR: vLLM server process died during startup"
        echo "Last 50 lines of vLLM server log:"
        tail -50 "$VLLM_LOG_FILE"
        exit 1
    fi
    
    if [ $i -eq 900 ]; then
        echo "vLLM server failed to start within 15 minutes"
        echo "Last 50 lines of vLLM server log:"
        tail -50 "$VLLM_LOG_FILE"
        kill $VLLM_PID 2>/dev/null
        exit 1
    fi
    if [ $((i % 30)) -eq 0 ]; then  # Show progress every 30 seconds
        echo "Still loading... ($i/900 seconds) - LLama3.3 70B model takes significant time"
        echo "Server status: $(ps -p $VLLM_PID > /dev/null 2>&1 && echo 'Running' || echo 'Stopped')"
        echo "GPU memory usage:"
        nvidia-smi --query-gpu=index,memory.used,memory.total --format=csv,noheader,nounits | head -4
    fi
    sleep 1
done

# Step 3: Run LLMGenerator with parameters matching gpt_oss_vllm
echo "Starting question generation with LLMGenerator..."
python -m synthetic_gen.generators.LLMQuestionGenerator \
    --input_source "$INPUT_SOURCE" \
    --input_type "$INPUT_TYPE" \
    --output_destination "$OUTPUT_DESTINATION" \
    --output_type "$OUTPUT_TYPE" \
    --model_name "$MODEL_NAME" \
    --temperature "$TEMPERATURE" \
    --backend "$BACKEND" \
    --num_workers "$NUM_WORKERS" \
    --vllm_url "$VLLM_URL" \
    --prompt_path "$PROMPT_PATH" \
    --results_file "$RESULTS_FILE" \
    --multi_prompt_mode \

EXIT_CODE=$?

# Step 4: Clean up
echo "Cleaning up..."
kill $VLLM_PID 2>/dev/null
wait $VLLM_PID 2>/dev/null

if [ $EXIT_CODE -eq 0 ]; then
    echo "Question generation completed successfully!"
    echo "Results saved to: $RESULTS_FILE"
    if [ "$OUTPUT_TYPE" = "local" ] && [ -n "$OUTPUT_DESTINATION" ]; then
        echo "Additional output at: $OUTPUT_DESTINATION"
    fi
else
    echo "Question generation failed with exit code $EXIT_CODE"
fi

echo "vLLM server log saved to: $VLLM_LOG_FILE"
exit $EXIT_CODE
