# Running LLM Generation with vLLM on MareNostrum

This guide explains how to run synthetic Q&A generation jobs using large language models (LLMs) with vLLM inference server on MareNostrum.

**Note:** This repository contains job configurations for MareNostrum. The actual generation code is in the [satcom-synthetic-data-gen](https://github.com/esa-sceva/satcom-synthetic-data-gen) repository.

## Overview

There are two approaches for generating synthetic Q&A data:

### 1. Direct vLLM Generation
Generate Q&A pairs directly from documents in a single stage using vLLM server.

### 2. Two-Stage Q&A Generation
A more controlled pipeline that:
- **Stage 1**: Generate questions from documents
- **Stage 2**: Generate answers from questions + source documents

Both approaches use vLLM (high-performance LLM inference) and support:

- **Llama 3.3 70B Instruct**
- **Mistral Large/Small**
- **Qwen 72B/32B**
- **Custom models**

The system starts a vLLM server, then runs the appropriate generator module to produce synthetic data.

## Files

### Direct vLLM Generation
1. Job Configuration: `configs/slurm_jobs/generation/vllm_generation`
2. Run Script: `scripts/slurm/generation/llm/run_vllm_generation.sh`
3. Submission Script: `scripts/slurm/generation/llm/submit_vllm_generation.sh`
4. vLLM Configs: `configs/vllm_configs/` (model-specific settings)

### Two-Stage Q&A Generation
**Questions Stage:**
1. Job Configuration: `configs/slurm_jobs/generation/qa/questions`
2. Run Script: `scripts/slurm/generation/qa/run_questions.sh`
3. Submission Script: `scripts/slurm/generation/qa/submit_questions.sh`

**Answers Stage:**
1. Job Configuration: `configs/slurm_jobs/generation/qa/answers`
2. Run Script: `scripts/slurm/generation/qa/run_answers.sh`
3. Submission Script: `scripts/slurm/generation/qa/submit_answers.sh`

## Quick Start - Direct vLLM Generation

### 1. Edit Configuration

```bash
nano configs/slurm_jobs/generation/vllm_generation
```

Key parameters:

```bash
# SLURM directives
JOB_NAME=qa_generation_wikipedia
CPUS_PER_TASK=80          # 20 per GPU is recommended
TIME=12:00:00
GRES=gpu:4                # 4 GPUs for 70B models, 1-2 for smaller models

# SLURM submission
ACCOUNT=<project_id>
QOS=acc_ehpc              # Use acc_debug for testing

# Generation parameters
INPUT_SOURCE="/gpfs/scratch/<project_id>/myfolder/data/wikipedia/"
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
cd /gpfs/projects/<project_id>/myfolder

./scripts/slurm/generation/llm/submit_vllm_generation.sh configs/slurm_jobs/generation/vllm_generation
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

---

## Quick Start - Two-Stage Q&A Generation

The two-stage approach provides more control by separating question and answer generation.

### Stage 1: Generate Questions

**1. Edit Configuration**

```bash
nano configs/slurm_jobs/generation/qa/questions
```

Key parameters:

```bash
# SLURM directives
JOB_NAME=questions_wikipedia
CPUS_PER_TASK=80
TIME=12:00:00
GRES=gpu:4

# SLURM submission
ACCOUNT=<project_id>
QOS=acc_ehpc

# Question generation parameters
INPUT_SOURCE="/gpfs/scratch/<project_id>/myfolder/data/wikipedia/"
OUTPUT_DESTINATION="/gpfs/projects/<project_id>/myfolder/questions"
MODEL_NAME="qwen2.5-72b"
TEMPERATURE="0.25"
NUM_WORKERS="12"
BACKEND="vllm"
PROMPT_PATH="/satcom-synthetic-data-gen/synthetic_gen/prompts/"
RESULTS_FILE="/gpfs/projects/<project_id>/myfolder/questions/questions_wikipedia.jsonl"
```

**2. Submit Question Generation**

```bash
./scripts/slurm/generation/qa/submit_questions.sh configs/slurm_jobs/generation/qa/questions
```

**3. Monitor**

```bash
squeue -u <hpc_username>
tail -f slurm_out_generation/*_questions_*.out
```

### Stage 2: Generate Answers

After questions are generated, run answer generation using the questions and source documents.

**1. Edit Configuration**

```bash
nano configs/slurm_jobs/generation/qa/answers
```

Key parameters:

```bash
# SLURM directives
JOB_NAME=answers_wikipedia
CPUS_PER_TASK=80
TIME=12:00:00
GRES=gpu:4

# SLURM submission
ACCOUNT=<project_id>
QOS=acc_ehpc

# Answer generation parameters
QUESTIONS_FILE="/gpfs/projects/<project_id>/myfolder/questions/questions_wikipedia.jsonl"  # From Stage 1
DOCS_SOURCE="/gpfs/scratch/<project_id>/myfolder/data/wikipedia/"                       # Original documents
OUTPUT_DESTINATION="/gpfs/projects/<project_id>/myfolder/answers"
MODEL_NAME="qwen2.5-72b"
TEMPERATURE="0.25"
NUM_WORKERS="12"
BACKEND="vllm"
RESULTS_FILE="/gpfs/projects/<project_id>/myfolder/answers/answers_wikipedia.jsonl"
```

**2. Submit Answer Generation**

```bash
./scripts/slurm/generation/qa/submit_answers.sh configs/slurm_jobs/generation/qa/answers
```

**3. Monitor**

```bash
squeue -u <hpc_username>
tail -f slurm_out_generation/*_answers_*.out
```

---

## When to Use Which Approach?

### Use Direct vLLM Generation When:
- You want simple, fast Q&A generation
- Quality control happens after generation
- You're generating large volumes quickly

### Use Two-Stage Q&A Generation When:
- You need more control over question quality
- You want to review/filter questions before generating answers
- You're generating from diverse document types
- You want to optimize prompts separately for questions vs answers
- You need to generate answers from multiple question sources

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

Higher value means more likely to be used for generation.


## How It Works

### Direct vLLM Generation

1. **Environment Setup**: Activates venv, sets HF_HOME, enables offline mode
2. **Model Verification**: Checks that model files exist at specified path
3. **vLLM Server Start**: Launches vLLM with proper tensor parallelism
4. **Wait for Ready**: Polls server until it's accepting requests (up to 5 minutes)
5. **Run Generator**: Executes LLMGenerator with specified parameters
6. **Cleanup**: Stops vLLM server and reports results

### Two-Stage Q&A Generation

**Stage 1 - Questions:**
1. Environment setup and model verification
2. Start vLLM server
3. Generate questions from documents using question-generation prompts
4. Save questions to JSONL file
5. Cleanup

**Stage 2 - Answers:**
1. Environment setup and model verification
2. Start vLLM server
3. Load questions from Stage 1
4. Load source documents
5. Generate answers using questions + documents + answer-generation prompts
6. Save final Q&A pairs to JSONL file
7. Cleanup

## Output Files

### Direct vLLM Generation

- **Results**: `RESULTS_FILE` (JSONL format with Q&A pairs)
- **Standard Out**: `slurm_out_generation/<job_name>_<job_id>.out`
- **Standard Err**: `slurm_out_generation/<job_name>_<job_id>.err`
- **vLLM Logs**: `slurm_out_generation/<job_name>_<job_id>_vllm_server.log`

### Two-Stage Q&A Generation

**Stage 1 Output:**
- **Questions**: `questions/<dataset>_questions.jsonl` (JSONL format with questions + context)
- **Logs**: `slurm_out_generation/*_questions_<job_id>.*`

**Stage 2 Output:**
- **Answers**: `answers/<dataset>_answers.jsonl` (JSONL format with questions + answers + context)
- **Logs**: `slurm_out_generation/*_answers_<job_id>.*`

### Output Format Examples

**Direct Generation:**
```jsonl
{
  "question": "What is satellite communication?",
  "answer": "Satellite communication is...",
  "context": "Document text...",
  "model": "llama3.3-70B"
}
```

**Questions Stage:**
```jsonl
{
  "question": "What is satellite communication?",
  "context": "Document text...",
  "doc_id": "arxiv_12345"
}
```

**Answers Stage:**
```jsonl
{
  "question": "What is satellite communication?",
  "answer": "Satellite communication is...",
  "context": "Document text...",
  "doc_id": "arxiv_12345",
  "model": "qwen2.5-72b"
}
```

## Monitoring

```bash
# Job status
squeue -u <hpc_username>
scontrol show job <job_id>

# Generation progress
tail -f slurm_out_generation/*_<job_id>.out

# vLLM server (look for "Uvicorn running...")
tail -f slurm_out_generation/*_<job_id>_vllm_server.log

# Cancel job
scancel <job_id>
```

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
1. Increase NUM_WORKERS
2. Check GPU utilization: `nvidia-smi` (in job)
3. Use smaller prompts

### Job Killed

**Symptom**: Job terminates unexpectedly

**Solutions**:
1. Check time limit: Increase TIME in config
2. Check account quota: `squeue -u <hpc_username>`
3. Review error logs for OOM or other issues




## Custom Models

1. Set `MODEL_NAME="custom-name"` in config
2. Update model path in run script
3. Adjust GPU count and tensor-parallel-size based on model size
4. Update `--served-model-name` in vLLM command



## Typical Workflows

**Direct Generation:**
```bash
./scripts/slurm/generation/llm/submit_vllm_generation.sh configs/slurm_jobs/generation/vllm_generation
squeue -u <hpc_username>  # Monitor
# Optional: grade with qa_curation job
```

**Two-Stage Generation:**
```bash
# 1. Questions
./scripts/slurm/generation/qa/submit_questions.sh configs/slurm_jobs/generation/qa/questions
# 2. Review (optional): head -100 questions/output.jsonl
# 3. Answers
./scripts/slurm/generation/qa/submit_answers.sh configs/slurm_jobs/generation/qa/answers
# Optional: grade with qa_curation job
```

## Additional Resources

- [satcom-synthetic-data-gen Repository](https://github.com/esa-sceva/satcom-synthetic-data-gen) - Core generation code
- [Main README](../README.md) - Overview and setup
- [Chunk Evaluation Guide](chunk_evaluation_setup.md) - Document preprocessing
- [Q&A Grading Guide](evaluation_setup.md) - Q&A quality assessment
- [vLLM Documentation](https://docs.vllm.ai/)
- [MareNostrum User Guide](https://www.bsc.es/user-support/mn4.php)

