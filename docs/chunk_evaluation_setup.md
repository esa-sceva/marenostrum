# Running Chunk Evaluation on MareNostrum

This guide explains how to run chunk evaluation jobs on MareNostrum using the SLURM job scheduler.

**Note:** This repository contains job configurations for MareNostrum. The actual chunk evaluation code is in the [satcom-synthetic-data-gen](https://github.com/esa-sceva/satcom-synthetic-data-gen) repository.

## Overview

The chunk evaluation jobs (module internally named `chunk_evaluation`) process document chunks and evaluate them using reward models (such as UltraRM) to score their quality. This is useful for filtering high-quality content for synthetic data generation.

## Files

The following files support running chunk evaluation:

1. **Job Configuration**: `configs/slurm_jobs/evaluation/chunk/chunk_evaluation`
2. **Run Script**: `scripts/slurm/evaluation/chunk/run_chunk_evaluation.sh`
3. **Submission Script**: `scripts/slurm/evaluation/chunk/submit_chunk_evaluation.sh`

## Usage

### Step 1: Customize the Configuration (Optional)

Edit the job configuration file if needed:

```bash
nano configs/slurm_jobs/evaluation/chunk/chunk_evaluation
```

Key parameters you might want to adjust:

- `TIME`: Job time limit (default: 10:00:00)
- `CPUS_PER_TASK`: CPU cores (default: 20)
- `GRES`: GPU resources (default: gpu:1)
- `ACCOUNT`: Your SLURM account (e.g., <project_id>)
- `QOS`: Quality of service (acc_debug for testing, acc_ehpc for production)
- `INPUT_SOURCE`: Path to your data (e.g., `/gpfs/projects/<project_id>/myfolder/data/wikipedia/`)
- `PROMPT_TEMPLATE`: Path to your prompt template
- `OUTPUT_DESTINATION`: Where to save results (e.g., `chunks/wikipedia`)
- `SCORE_THRESHOLD`: Scoring threshold (default: -1000)
- `MAX_CHUNK_SIZE`: Maximum chunk size in tokens (default: 4096)
- `OFFLINE_MODE`: 1 for offline (cached models only), 0 for online

### Step 2: Submit the Job

Run the submission script:

```bash
./scripts/slurm/evaluation/chunk/submit_chunk_evaluation.sh configs/slurm_jobs/evaluation/chunk/chunk_evaluation
```

### Step 3: Monitor the Job

Check job status:

```bash
squeue -u $USER
```

View job output:

```bash
tail -f slurm_out/chunk_eval_*.out
```

View job errors:

```bash
tail -f slurm_out/chunk_eval_*.err
```

## Configuration Example

```bash
# SLURM directives
JOB_NAME=wikipedia_chunks
WORK_DIR=.
OUT_FILE=slurm_out/chunk_eval_%j.out
ERR_FILE=slurm_out/chunk_eval_%j.err
NTASKS=1
CPUS_PER_TASK=20
TIME=10:00:00
GRES=gpu:1

# SLURM submission options
ACCOUNT=<project_id>
QOS=acc_ehpc

# Job-specific arguments
INPUT_SOURCE="/gpfs/projects/<project_id>/myfolder/data/wikipedia/"
INPUT_TYPE="local"
PROMPT_TEMPLATE="/satcom-synthetic-data-gen/synthetic_gen/prompts/ultraRM_prompt.yaml"
OUTPUT_DESTINATION="chunks/wikipedia"
OUTPUT_TYPE="local"
SCORE_THRESHOLD="-1000"
MAX_CHUNK_SIZE="4096"
LOCAL_JSON_PATH="./_analytics_/wikipedia.json"
LOGS_FOLDER="logs"

# Model loading mode (1 = offline, 0 = online)
OFFLINE_MODE=1
```

## What It Does

The chunk evaluation module:

1. **Loads documents** from the specified input source (local directory)
2. **Chunks documents** into smaller pieces (up to MAX_CHUNK_SIZE tokens)
3. **Evaluates chunks** using a reward model (UltraRM by default)
4. **Scores chunks** based on quality metrics
5. **Filters chunks** above the score threshold
6. **Outputs results** to the specified destination

## Output Files

- **Chunk files**: `OUTPUT_DESTINATION/*.jsonl` - Processed and scored chunks
- **Analytics**: `LOCAL_JSON_PATH` - Summary statistics and metadata
- **Logs**: `LOGS_FOLDER/` - Processing logs and errors
- **GPU logs**: `gpu_logs/gpu_usage_<job_id>.log` - GPU utilization tracking

## Original Command

This setup runs the equivalent of:

```bash
python -m synthetic_gen.data_processing.chunk_evaluation \
  --input_source "/workspace/satcom-synthetic-data-gen/data" \
  --input_type local \
  --prompt_template ./evaluators/prompts/ultraRM_prompt.yaml \
  --output_destination output \
  --output_type "local" \
  --score_threshold -12 \
  --max_chunk_size 4096 \
  --local_json_path "./selected_chunks_scores.json" \
  --logs_folder "logs"
```

## File Structure

```
satcom-marenostrum/
├── configs/slurm_jobs/evaluation/chunk/
│   └── chunk_evaluation                     # Job configuration
├── scripts/slurm/evaluation/chunk/
│   ├── run_chunk_evaluation.sh              # Execution script
│   └── submit_chunk_evaluation.sh           # Submission script
├── chunks/                                  # Output chunks (created automatically)
├── logs/                                    # Processing logs
├── gpu_logs/                                # GPU monitoring logs
└── slurm_out/                               # Job output logs (created automatically)
```

## Troubleshooting

### Model Not Found

If you see "ERROR: UltraRM model not found in cache":

1. Verify the model path in `HF_HOME` (default: `/gpfs/projects/<project_id>/myfolder/hf_cache`)
2. Ensure the model is downloaded and cached
3. Check that `OFFLINE_MODE=1` is set only if the model is cached

### Module Import Error

If you see "ERROR: chunk_evaluation module not found":

1. Verify the container has the module installed
2. Check that `PYTHONPATH` includes `/satcom-synthetic-data-gen`
3. Rebuild the container if necessary

### GPU Issues

If GPU is not being utilized:

1. Verify `GRES=gpu:1` is set in the config
2. Check GPU availability: `nvidia-smi`
3. Review GPU logs in `gpu_logs/gpu_usage_<job_id>.log`

### Line Ending Issues (Windows)

If scripts fail with syntax errors:

```bash
sed -i 's/\r$//' configs/slurm_jobs/evaluation/chunk/chunk_evaluation
sed -i 's/\r$//' scripts/slurm/evaluation/chunk/run_chunk_evaluation.sh
sed -i 's/\r$//' scripts/slurm/evaluation/chunk/submit_chunk_evaluation.sh
```

## Notes

- The setup uses the same Singularity container (`container.sif`) as other jobs
- GPU monitoring is included to track resource usage
- Output directories are created automatically
- The job uses the virtual environment at `/satcom-synthetic-data-gen/synthetic_gen/.venv`
- Logs are saved with timestamps and job IDs for easy tracking
- For large datasets, consider using multiple jobs with different input directories



## Additional Resources

- [satcom-synthetic-data-gen Repository](https://github.com/esa-sceva/satcom-synthetic-data-gen) - Core evaluation code
- [Main README](../README.md) - Overview and setup
- [LLM Generation Guide](llm_generation_vllm_setup.md) - Generate Q&A pairs
- [Evaluation Guide](evaluation_setup.md) - Q&A grading
- [Common Commands](../COMMANDS.md) - Quick reference

