#!/bin/bash

CONFIG_FILE="$1"
if [[ -z "$CONFIG_FILE" ]]; then
  echo "Usage: ./submit_answer_generation.sh <job_config>"
  echo "Example: ./submit_answer_generation.sh configs/slurm_jobs/answer_generation"
  exit 1
fi

# Load job configuration
source "$CONFIG_FILE"

# Create output directories
mkdir -p "$(dirname "$OUT_FILE")"
mkdir -p "$(dirname "$ERR_FILE")"
mkdir -p "$(dirname "$RESULTS_FILE")"
if [ "$OUTPUT_TYPE" = "local" ] && [ -n "$OUTPUT_DESTINATION" ]; then
  mkdir -p "$OUTPUT_DESTINATION"
fi

# Create temporary SLURM script
TMP_SLURM_SCRIPT=$(mktemp)

cat <<EOF > "$TMP_SLURM_SCRIPT"
#!/bin/bash
#SBATCH --job-name=$JOB_NAME
#SBATCH -D $WORK_DIR
#SBATCH --output=$OUT_FILE
#SBATCH --error=$ERR_FILE
#SBATCH --ntasks=$NTASKS
#SBATCH --cpus-per-task=$CPUS_PER_TASK
#SBATCH --time=$TIME
#SBATCH --gres=$GRES

export SRUN_CPUS_PER_TASK=\${SLURM_CPUS_PER_TASK}
echo "Job ID: \$SLURM_JOB_ID"
echo "Node: \$SLURMD_NODENAME"
echo "Timestamp: \$(date)"

module load singularity

echo "Running Answer Generation with vLLM:"
echo "- Questions file: $QUESTIONS_FILE"
echo "- Input source: $INPUT_SOURCE"
echo "- Output destination: $OUTPUT_DESTINATION"
echo "- Model: $MODEL_NAME"
echo "- Backend: $BACKEND (vLLM)"
echo "- Workers: $NUM_WORKERS"
echo "- Temperature: $TEMPERATURE"

# Export ALL config variables so they're available in singularity
export MODEL_NAME="$MODEL_NAME"
export QUESTIONS_FILE="$QUESTIONS_FILE"
export INPUT_SOURCE="$INPUT_SOURCE"
export INPUT_TYPE="$INPUT_TYPE"
export OUTPUT_DESTINATION="$OUTPUT_DESTINATION"
export OUTPUT_TYPE="$OUTPUT_TYPE"
export PROMPT_PATH="$PROMPT_PATH"
export RESULTS_FILE="$RESULTS_FILE"
export N_DOCS="$N_DOCS"
export N_SHOTS="$N_SHOTS"
export TEMPERATURE="$TEMPERATURE"
export MAX_RETRIES="$MAX_RETRIES"
export BACKEND="$BACKEND"
export NUM_WORKERS="$NUM_WORKERS"
export VLLM_URL="$VLLM_URL"
export S3_BUCKET="$S3_BUCKET"
export VLLM_LOG_FILE="slurm_out_answer_generation/mdpi_13_\${SLURM_JOB_ID}_vllm_server.log"

# Run the answer generation job using singularity
singularity exec --nv container.sif /bin/bash /gpfs/projects/<project_id>/myfolder/scripts/slurm/run_answer_generation.sh
EOF

echo "Submitting Answer Generation job..."
echo "Configuration loaded from: $CONFIG_FILE"
echo "Account: $ACCOUNT"
echo "QOS: $QOS"

# Submit job
sbatch -A "$ACCOUNT" -q "$QOS" "$TMP_SLURM_SCRIPT"

# Clean up temporary script
rm "$TMP_SLURM_SCRIPT"

