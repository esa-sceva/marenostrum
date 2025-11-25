# Running Q&A Evaluation Jobs on MareNostrum

This guide explains how to run evaluation jobs that use LLM-as-judge to assess and grade the quality of generated Q&A pairs during the synthetic data generation process.

## Overview

Evaluation jobs use large language models (LLM-as-judge) via vLLM to grade and score Q&A pairs generated during the synthetic data generation pipeline. The system evaluates multiple quality dimensions and filters Q&A pairs based on configurable thresholds.

**Important:** This repository contains job configurations for running on MareNostrum. The actual evaluation/grading code (`filtering_low_grades` module) is part of the [satcom-synthetic-data-gen](https://github.com/esa-sceva/satcom-synthetic-data-gen) repository.

## Purpose

- **Grade Q&A Quality**: Use LLMs to score generated Q&A pairs on multiple dimensions
- **Filter Content**: Select high-quality Q&A pairs based on threshold criteria
- **Quality Control**: Ensure generated data meets quality standards
- **Feedback Loop**: Identify patterns in good/bad generations

## Files

1. **Job Configuration**: `configs/slurm_jobs/evaluation/qa_curation/evaluation`
2. **Run Script**: `scripts/slurm/evaluation/qa_curation/run_evaluation.sh`
3. **Submission Script**: `scripts/slurm/evaluation/qa_curation/submit_evaluation.sh`

## Quick Start

### 1. Edit Configuration

```bash
nano configs/slurm_jobs/evaluation/qa_curation/evaluation
```

Key parameters:

```bash
# SLURM directives
JOB_NAME=wikipedia
WORK_DIR=.
OUT_FILE=slurm_out_evaluation/wikipedia_eval_%j.out
ERR_FILE=slurm_out_evaluation/wikipedia_eval_%j.err
VLLM_LOG_FILE=slurm_out_evaluation/wikipedia_eval_%j_vllm_server.log
NTASKS=1
CPUS_PER_TASK=80
TIME=12:00:00
GRES=gpu:4              # 4 GPUs for 70B models

# SLURM submission options
ACCOUNT=<project_id>
QOS=acc_ehpc            # Use acc_debug for testing

# Evaluation parameters
MODEL_NAME="qwen2.5-72b"
DATASET_PATH="/gpfs/projects/<project_id>/myfolder/results/qa_wikipedia.jsonl"
RESULTS_PATH="/gpfs/projects/<project_id>/myfolder/grades/qa_grades_wikipedia.jsonl"
OUTPUT_PATH="/gpfs/projects/<project_id>/myfolder/filtered_qas/filtered_qa_wikipedia.jsonl"
PROMPT_PATH="/satcom-synthetic-data-gen/synthetic_gen/prompts/grade_qas.yaml"
THRESHOLD="4"                               # Overall minimum score (1-5 scale)
PERTINENCE_THRESHOLD="4"                    # Question relevance to context
CONTEXTUAL_RELEVANCE_THRESHOLD="4"          # Answer relevance to context
CORRECTNESS_THRESHOLD="4"                   # Answer correctness
FILTER_LOGIC="AND"                          # "AND" or "OR" logic for thresholds
N_DOCS="-1"                                 # Number of documents (-1 = all)
N_SHOTS="4"                                 # Few-shot examples for grading
TEMPERATURE="0.25"                          # LLM temperature
BACKEND="vllm"
NUM_WORKERS="12"                            # Parallel workers
```

### 2. Submit Job

```bash
ssh <hpc_username>@alogin2.bsc.es
cd /gpfs/projects/<project_id>/satcom

./scripts/slurm/evaluation/qa_curation/submit_evaluation.sh configs/slurm_jobs/evaluation/qa_curation/evaluation
```

### 3. Monitor Job

```bash
# Check job status
squeue -u <hpc_username>

# View grading progress
tail -f slurm_out_evaluation/*_eval_*.out

# Check vLLM server logs
tail -f slurm_out_evaluation/*_vllm_server.log
```

## How It Works

The evaluation process:

1. **Start vLLM Server**: Launches vLLM with the grading model (e.g., Qwen2.5 72B)
2. **Wait for Ready**: Waits for model to load (up to 15 minutes for 72B models)
3. **Run Grading**: Executes `filtering_low_grades` module to grade Q&A pairs
4. **Apply Filters**: Filters Q&A pairs based on threshold criteria
5. **Save Results**: Outputs graded and filtered Q&A pairs
6. **Cleanup**: Stops vLLM server

## Configuration Details

### Input/Output Parameters

- **MODEL_NAME**: LLM model to use for grading (e.g., "qwen2.5-72b", "llama3.3-70b")
- **DATASET_PATH**: Path to generated Q&A pairs to grade (JSONL format)
- **RESULTS_PATH**: Path to save all graded Q&A pairs with scores
- **OUTPUT_PATH**: Path to save filtered (high-quality) Q&A pairs
- **PROMPT_PATH**: Path to grading prompt template

### Grading Dimensions

The LLM-as-judge evaluates Q&A pairs on multiple dimensions (typically 1-5 scale):

1. **Pertinence**: Is the question relevant to the provided context?
2. **Contextual Relevance**: Is the answer grounded in the context?
3. **Correctness**: Is the answer factually correct?
4. **Overall Quality**: General quality assessment

### Threshold Parameters

- **THRESHOLD**: Minimum overall score to keep a Q&A pair
- **PERTINENCE_THRESHOLD**: Minimum pertinence score
- **CONTEXTUAL_RELEVANCE_THRESHOLD**: Minimum contextual relevance score
- **CORRECTNESS_THRESHOLD**: Minimum correctness score
- **FILTER_LOGIC**: 
  - `"AND"`: Q&A must pass ALL thresholds
  - `"OR"`: Q&A must pass ANY threshold

### GPU Requirements

| Model Size | GPUs | CPUS_PER_TASK |
|------------|------|---------------|
| 70B+ (Qwen2.5 72B, Llama 70B) | 4 | 80 | 
| 30B-70B | 2-4 | 40-80 | 
| 7B-30B | 1-2 | 20-40 |


## Output Files

The evaluation job generates:

- RESULTS_PATH: All Q&A pairs with detailed scores for each dimension
- OUTPUT_PATH: Filtered Q&A pairs that passed threshold criteria
- VLLM_LOG_FILE: vLLM server logs

Example output structure:

```
grades/
└── qa_grades_wikipedia.jsonl          # All Q&As with scores

filtered_qas/
└── filtered_qa_wikipedia.jsonl        # High-quality Q&As only

slurm_out_evaluation/
├── wikipedia_eval_<job_id>.out        # Job output log
├── wikipedia_eval_<job_id>.err        # Job error log
└── wikipedia_eval_<job_id>_vllm_server.log  # vLLM server log
```

## Output Format

### Graded Q&A Pairs (RESULTS_PATH)

```jsonl
{
  "question": "What is satellite communication?",
  "answer": "Satellite communication is...",
  "context": "Document context...",
  "pertinence": 5,
  "contextual_relevance": 5,
  "correctness": 4,
  "overall_score": 4.7,
  "passed_filter": true,
  "model": "qwen2.5-72b"
}
```

### Filtered Q&A Pairs (OUTPUT_PATH)

Contains only Q&A pairs that passed the threshold criteria, in the same format.

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

### Grading Progress

The output log shows:
- vLLM server startup progress
- Q&A pairs graded
- Current scores
- Filtering statistics
- Estimated time remaining

```bash
tail -f slurm_out_evaluation/*_eval_*.out
```

### vLLM Server Status

Check if vLLM server is running properly:

```bash
tail -f slurm_out_evaluation/*_vllm_server.log
```

Look for:
- "Uvicorn running on..." = Server started
- "Loading model..." = Model loading
- Request logs = Processing grading requests

### Check Results

```bash
# Count all graded pairs
wc -l /gpfs/projects/<project_id>/myfolder/grades/qa_grades_wikipedia.jsonl

# Count filtered (high-quality) pairs
wc -l /gpfs/projects/<project_id>/myfolder/filtered_qas/filtered_qa_wikipedia.jsonl

# View sample graded pair
head -1 /gpfs/projects/<project_id>/myfolder/grades/qa_grades_wikipedia.jsonl | jq '.'

# Calculate filtering rate
echo "scale=2; $(wc -l < filtered_qas/filtered_qa_wikipedia.jsonl) * 100 / $(wc -l < grades/qa_grades_wikipedia.jsonl)" | bc
```

## Troubleshooting

### vLLM Server Won't Start

**Symptom**: "vLLM server failed to start within 15 minutes"

**Solutions**:
1. Check GPU allocation matches tensor-parallel-size (4 GPUs for 72B)
2. Verify model path in HF_HOME: `/gpfs/projects/<project_id>/myfolder/qwen_72B`
3. Check vLLM logs for CUDA errors
4. Ensure sufficient GPU memory (72B needs 4x H100 GPUs)
5. Check for existing vLLM processes: `pgrep -f vllm`

### Grading Model Not Found

**Symptom**: "ERROR: Qwen2.5 72B model not found!"

**Solutions**:
1. Verify model exists at: `/gpfs/projects/<project_id>/myfolder/qwen_72B/models/`
2. Check HF_HOME is set correctly in run script
3. Ensure model was downloaded completely
4. Download model if missing (see main README)

### Out of Memory

**Symptom**: "CUDA out of memory" or process killed

**Solutions**:
1. Reduce NUM_WORKERS (try 8 or 6)
2. Ensure GRES=gpu:4 for 72B models
3. Check no other processes are using GPUs
4. Reduce --max-model-len in vLLM if needed

### Slow Grading

**Symptom**: Job runs much longer than expected

**Solutions**:
1. Increase NUM_WORKERS (try 16-20 for 4 GPUs)
2. Check GPU utilization with logs
3. Reduce N_DOCS to test on subset first
4. Ensure vLLM server is responding (check logs)

### All Q&As Filtered Out

**Symptom**: OUTPUT_PATH has very few or no Q&A pairs

**Solutions**:
1. Lower thresholds (try 3 instead of 4)
2. Change FILTER_LOGIC from "AND" to "OR"
3. Review graded scores to understand quality
4. Check if generation quality needs improvement

### Process Killed During Startup

**Symptom**: "vLLM server process died immediately after startup"

**Solutions**:
1. Check vLLM log for specific error
2. Verify GPU availability: `nvidia-smi`
3. Kill existing vLLM processes if any
4. Check CUDA compatibility

## Integration with Generation Pipeline

Typical workflow:

1. **Generate Q&A**: Run LLM generation job
2. **Grade Q&A**: Run evaluation job to score pairs
3. **Filter**: Keep only high-quality pairs based on thresholds
4. **Analyze**: Review filtered results
5. **Upload**: Transfer filtered results to S3

```bash
# 1. Generate Q&A
./scripts/slurm/submit_llm_generation_vllm.sh configs/slurm_jobs/llm_generation_vllm

# 2. Wait for completion
squeue -u <hpc_username>

# 3. Grade Q&A pairs
./scripts/slurm/submit_evaluation.sh configs/slurm_jobs/evaluation

# 4. Wait for grading
squeue -u <hpc_username>

# 5. Check filtering statistics
wc -l grades/qa_grades_wikipedia.jsonl
wc -l filtered_qas/filtered_qa_wikipedia.jsonl

# 6. Upload filtered results
rclone copy bsc:/gpfs/projects/<project_id>/myfolder/filtered_qas/filtered_qa_wikipedia.jsonl \
  s3:<bucket-name>/synthetic-data-gen/approved/ --progress -vv
```

## Best Practices

1. **Test on Samples**: Use N_DOCS=100 for initial testing
2. **Tune Thresholds**: Start with lower thresholds (3), then increase
3. **Use Few-Shot**: N_SHOTS=4 provides good grading consistency
4. **Monitor Filtering**: Aim for 60-80% pass rate
5. **Save All Grades**: Keep RESULTS_PATH for later analysis
6. **Check Model Logs**: Review vLLM logs for any issues

## Performance Tips

1. **Use GPU**: vLLM significantly accelerates grading
2. **Parallel Workers**: NUM_WORKERS=12-20 for 4 GPUs
3. **Batch Effectively**: Higher workers = better throughput
4. **Model Selection**: Qwen2.5 72B provides good balance of quality and speed
5. **Temperature**: 0.25 provides consistent grading

## Grading Criteria

The LLM-as-judge evaluates based on:

- **Pertinence** (1-5): Is the question relevant and useful given the context?
- **Contextual Relevance** (1-5): Is the answer grounded in the provided context?
- **Correctness** (1-5): Is the answer factually accurate and complete?

The grading prompt uses few-shot examples (N_SHOTS) to ensure consistent evaluation. See the [satcom-synthetic-data-gen](https://github.com/esa-sceva/satcom-synthetic-data-gen) repository for detailed grading prompts and criteria.

## Filter Logic Examples

### AND Logic (Strict)
```bash
FILTER_LOGIC="AND"
THRESHOLD="4"
PERTINENCE_THRESHOLD="4"
CONTEXTUAL_RELEVANCE_THRESHOLD="4"
CORRECTNESS_THRESHOLD="4"
```
Q&A must score ≥4 on ALL dimensions to pass.

### OR Logic (Lenient)
```bash
FILTER_LOGIC="OR"
THRESHOLD="4"
PERTINENCE_THRESHOLD="4"
CONTEXTUAL_RELEVANCE_THRESHOLD="4"
CORRECTNESS_THRESHOLD="4"
```
Q&A must score ≥4 on ANY dimension to pass.

### Selective Filtering
```bash
FILTER_LOGIC="AND"
THRESHOLD="3"                               # Lower overall threshold
PERTINENCE_THRESHOLD="5"                    # But require high pertinence
CONTEXTUAL_RELEVANCE_THRESHOLD="4"
CORRECTNESS_THRESHOLD="4"
```

## Additional Resources

- [satcom-synthetic-data-gen](https://github.com/esa-sceva/satcom-synthetic-data-gen) repository - Core generation & evaluation code
- [Main README](../README.md) - Overview and setup
- [LLM Generation Guide](llm_generation_vllm_setup.md) - Generate Q&A pairs
- [Chunk Evaluation Guide](chunk_evaluation_setup.md) - Document preprocessing
- [Common Commands](../COMMANDS.md) - Quick reference
