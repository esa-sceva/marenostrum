# Running s3_chunk_eval_upload on MareNostrum

This guide explains how to run the `s3_chunk_eval_upload` command on MareNostrum using the SLURM job scheduler.

## Files Created

The following files have been created to support running `s3_chunk_eval_upload`:

1. **Job Configuration**: `configs/slurm_jobs/s3_chunk_eval_upload`
2. **Run Script**: `scripts/slurm/run_s3_chunk_eval.sh`
3. **Submission Script**: `scripts/slurm/submit_s3_chunk_eval.sh`

## Usage

### Step 1: Customize the Configuration (Optional)

Edit the job configuration file if needed:

```bash
nano configs/slurm_jobs/s3_chunk_eval_upload
```

Key parameters you might want to adjust:
- `TIME`: Job time limit (currently 02:00:00)
- `CPUS_PER_TASK`: CPU cores (currently 20)
- `GRES`: GPU resources (currently gpu:1)
- `ACCOUNT`: Your SLURM account (currently <project_id>)
- `QOS`: Quality of service (currently acc_debug)
- `INPUT_SOURCE`: Path to your data
- `PROMPT_TEMPLATE`: Path to your prompt template
- `OUTPUT_DESTINATION`: Where to save results
- `SCORE_THRESHOLD`: Scoring threshold (currently -12)

### Step 2: Submit the Job

Run the submission script:

```bash
./scripts/slurm/submit_s3_chunk_eval.sh configs/slurm_jobs/s3_chunk_eval_upload
```

### Step 3: Monitor the Job

Check job status:
```bash
squeue -u $USER
```

View job output:
```bash
tail -f slurm_out/s3_chunk_eval_*.out
```

View job errors:
```bash
tail -f slurm_out/s3_chunk_eval_*.err
```

## Original Command

This setup runs the equivalent of:
```bash
python -m s3_chunk_eval_upload \
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
├── configs/slurm_jobs/s3_chunk_eval_upload    # Job configuration
├── scripts/slurm/
│   ├── run_s3_chunk_eval.sh                   # Execution script
│   └── submit_s3_chunk_eval.sh                # Submission script
└── slurm_out/                                 # Job output logs (created automatically)
```

## Notes

- The setup uses the same singularity container (`container.sif`) as other jobs
- GPU monitoring is included to track resource usage
- Output directories are created automatically
- The job uses the same virtual environment path as other scripts (`/mistral-synth-gen/.venv`)
- Logs are saved with timestamps and job IDs for easy tracking
