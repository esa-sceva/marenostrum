# Running LLM Generation with vLLM on MareNostrum

This guide explains how to run synthetic Q&A generation jobs using large language models (LLMs) with vLLM inference server on MareNostrum.

**Note:** This repository contains job configurations for MareNostrum. The actual generation code is in the [satcom-synthetic-data-gen](https://github.com/esa-sceva/satcom-synthetic-data-gen) repository.

## Overview

The LLM generation jobs use vLLM (high-performance LLM inference) to generate synthetic Q&A data from document chunks. It supports:

- **Llama 3.3 70B Instruct**
- **Mistral Large/Small**
- **Qwen 72B/32B**
- **Custom models**

The system starts a vLLM server, then runs the LLMGenerator to produce synthetic data using various prompt templates.

## Files

1. **Job Configuration**: `configs/slurm_jobs/llm_generation_vllm`
2. **Run Script**: `scripts/slurm/run_llm_generation_vllm.sh`
3. **Submission Script**: `scripts/slurm/submit_llm_generation_vllm.sh`
4. **vLLM Configs**: `configs/vllm_configs/` (model-specific settings)

## Quick Start

### 1. Edit Configuration

```bash
nano configs/slurm_jobs/llm_generation_vllm
```

Key parameters:

```bash
# SLURM directives
JOB_NAME=qa_generation_mdpi
CPUS_PER_TASK=80          # 20 per GPU is recommended
TIME=12:00:00
GRES=gpu:4                # 4 GPUs for 70B models, 2 for smaller models

# SLURM submission
ACCOUNT=<project_id>
QOS=acc_ehpc              # Use acc_debug for testing

# Generation parameters
INPUT_SOURCE="/gpfs/scratch/<project_id>/myfolder/data/mdpi_17/"
OUTPUT_DESTINATION="/gpfs/projects/<project_id>/myfolder/results"
MODEL_NAME="llama3.3-70B"
TEMPERATURE="0.25"        # Lower = more deterministic
NUM_WORKERS="8"           # Parallel workers
BACKEND="vllm"
VLLM_URL="http://localhost:8000/v1"
PROMPT_PATH="/satcom-synthetic-data-gen/synthetic_gen/prompts/"
RESULTS_FILE="/gpfs/projects/<project_id>/myfolder/results/qa_output.jsonl"
```

### 2. Submit Job

```bash
ssh <hpc_username>@alogin2.bsc.es
cd /gpfs/projects/<project_id>/satcom

./scripts/slurm/submit_llm_generation_vllm.sh configs/slurm_jobs/llm_generation_vllm
```

### 3. Monitor Job

```bash
# Check job status
squeue -u <hpc_username>

# View generation progress
tail -f slurm_out_generation/*_<job_id>.out

# Check vLLM server logs
tail -f slurm_out_generation/*_<job_id>_vllm_server.log
```

## Configuration Details

### GPU Requirements

| Model Size | GPUs | tensor-parallel-size | CPUS_PER_TASK |
|------------|------|---------------------|---------------|
| 70B        | 4    | 4                   | 80            |
| 32B        | 2    | 2                   | 40            |
| 7B-15B     | 1    | 1                   | 20            |

### Model Paths

Models should be in HuggingFace cache format:

```bash
/gpfs/projects/<project_id>/myfolder/llama_70B/models/models--meta-llama--Llama-3.3-70B-Instruct/snapshots/<hash>/
```

The script automatically sets:
- `HF_HOME=/gpfs/projects/<project_id>/myfolder/llama_70B`
- `TRANSFORMERS_OFFLINE=1`
- `HF_HUB_OFFLINE=1`

### Prompt Configuration

The `multi_prompt_mode` uses multiple prompt templates with weighted probabilities:

```bash
--prompt_probabilities '{
  "QA_generator_docs_prompt": 1.5,
  "qa_simple_prompt": 2,
  "ultraRM_prompt": 0.0,
  "grade_qas": 0.0,
  "MCQAs_prompt": 0.75,
  "conversation_prompt": 1.0,
  "cot_prompt": 1.25
}'
```

Higher values = more likely to be used for generation.

## Complete Configuration Example

```bash
# SLURM directives for Llama 3.3 70B with vLLM
JOB_NAME=arxiv_qa_generation
WORK_DIR=.
OUT_FILE=slurm_out_generation/arxiv_llama70b_%j.out
ERR_FILE=slurm_out_generation/arxiv_llama70b_%j.err
VLLM_LOG_FILE=slurm_out_generation/arxiv_llama70b_%j_vllm_server.log
NTASKS=1
CPUS_PER_TASK=80
TIME=12:00:00
GRES=gpu:4

# SLURM submission options
ACCOUNT=<project_id>
QOS=acc_ehpc

# Job-specific arguments for Llama 3.3 70B vLLM
INPUT_SOURCE="/gpfs/scratch/<project_id>/myfolder/data/arxiv/"
INPUT_TYPE="local"
OUTPUT_DESTINATION="/gpfs/projects/<project_id>/myfolder/results"
OUTPUT_TYPE="local"
MODEL_NAME="llama3.3-70B"
TEMPERATURE="0.25"
MAX_RETRIES="3"
PROMPT_PATH="/satcom-synthetic-data-gen/synthetic_gen/prompts/"
RESULTS_FILE="/gpfs/projects/<project_id>/myfolder/results/qa_arxiv_llama70b.jsonl"
BACKEND="vllm"
NUM_WORKERS="8"
VLLM_URL="http://localhost:8000/v1"
S3_BUCKET=""
```

## How It Works

1. **Environment Setup**: Activates venv, sets HF_HOME, enables offline mode
2. **Model Verification**: Checks that model files exist at specified path
3. **vLLM Server Start**: Launches vLLM with proper tensor parallelism
4. **Wait for Ready**: Polls server until it's accepting requests (up to 5 minutes)
5. **Run Generator**: Executes LLMGenerator with specified parameters
6. **Cleanup**: Stops vLLM server and reports results

## Output Files

- **Results**: `RESULTS_FILE` (JSONL format with generated Q&As)
- **Standard Out**: `slurm_out_generation/<job_name>_<job_id>.out`
- **Standard Err**: `slurm_out_generation/<job_name>_<job_id>.err`
- **vLLM Logs**: `slurm_out_generation/<job_name>_<job_id>_vllm_server.log`

## Monitoring

### Job Status

```bash
# List your jobs
squeue -u <hpc_username>

# Detailed job info
scontrol show job <job_id>

# Cancel job
scancel <job_id>
```

### Generation Progress

The output file shows:
- Documents processed
- Q&As generated
- Success/failure rates
- Time elapsed

```bash
tail -f slurm_out_generation/*_<job_id>.out
```

### vLLM Server Status

Check if vLLM is running properly:

```bash
tail -f slurm_out_generation/*_<job_id>_vllm_server.log
```

Look for:
- "Uvicorn running on..." = Server started
- "Loading model..." = Model loading
- Request logs = Processing queries

## Troubleshooting

### vLLM Server Won't Start

**Symptom**: "vLLM server failed to start within 5 minutes"

**Solutions**:
1. Check GPU allocation matches tensor-parallel-size
2. Verify model path exists: `ls /gpfs/projects/<project_id>/myfolder/llama_70B/models/`
3. Check vLLM logs for errors
4. Ensure enough GPU memory (70B needs ~4xH100)

### Model Not Found

**Symptom**: "ERROR: Llama 3.3 70B model not found!"

**Solutions**:
1. Verify HF_HOME path in script
2. Check model directory structure:
   ```bash
   find /gpfs/projects/<project_id>/myfolder/llama_70B -name "config.json"
   ```
3. Download model if missing (see main README)

### Out of Memory

**Symptom**: "CUDA out of memory" in vLLM logs

**Solutions**:
1. Increase GPU count (GRES)
2. Reduce max-model-len: `--max-model-len 32000`
3. Use a smaller model
4. Reduce NUM_WORKERS

### Slow Generation

**Symptom**: Very slow Q&A generation

**Solutions**:
1. Increase NUM_WORKERS (but not beyond available GPUs * 2)
2. Check GPU utilization: `nvidia-smi` (in job)
3. Reduce TEMPERATURE for faster sampling
4. Use smaller prompts

### Job Killed

**Symptom**: Job terminates unexpectedly

**Solutions**:
1. Check time limit: Increase TIME in config
2. Check account quota: `squeue -u <hpc_username>`
3. Review error logs for OOM or other issues

## Performance Tips

1. **Batch Size**: NUM_WORKERS=8 is good for 4 GPUs
2. **Temperature**: 0.2-0.3 for factual Q&A, 0.7-1.0 for creative
3. **Model Length**: Adjust `--max-model-len` based on your prompts
4. **Disk Space**: Use `/gpfs/scratch/` for large intermediate files

## Advanced: Custom Models

To use a different model:

1. Update model path in config:
   ```bash
   MODEL_NAME="custom-model-name"
   ```

2. Modify run script to point to correct path:
   ```bash
   CUSTOM_MODEL_PATH="/gpfs/projects/<project_id>/myfolder/custom_model/"
   ```

3. Adjust tensor-parallel-size based on model size

4. Update served-model-name in vLLM launch command



## Additional Resources

- [satcom-synthetic-data-gen Repository](https://github.com/esa-sceva/satcom-synthetic-data-gen) - Core generation code
- [Main README](../README.md) - Overview and setup
- [Chunk Evaluation Guide](chunk_evaluation_setup.md) - Document preprocessing
- [Evaluation Guide](evaluation_setup.md) - Q&A grading
- [vLLM Documentation](https://docs.vllm.ai/)
- [MareNostrum User Guide](https://www.bsc.es/user-support/mn4.php)

