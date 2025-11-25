#!/bin/bash

CONFIG_FILE="$1"
if [[ -z "$CONFIG_FILE" ]]; then
  echo "Usage: ./submit_chunk_evaluation.sh <job_config>"
  echo "Example: ./submit_chunk_evaluation.sh configs/slurm_jobs/chunk_evaluation"
  exit 1
fi

# Load job configuration
source "$CONFIG_FILE"

# Create output directories
mkdir -p "$(dirname "$OUT_FILE")"
mkdir -p "$(dirname "$ERR_FILE")"

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

echo "Running chunk evaluation with:"
echo "- Input source: $INPUT_SOURCE"
echo "- Input type: $INPUT_TYPE"
echo "- Prompt template: $PROMPT_TEMPLATE"
echo "- Output destination: $OUTPUT_DESTINATION"
echo "- Output type: $OUTPUT_TYPE"
echo "- Score threshold: $SCORE_THRESHOLD"
echo "- Max chunk size: $MAX_CHUNK_SIZE"
echo "- Local JSON path: $LOCAL_JSON_PATH"
echo "- Logs folder: $LOGS_FOLDER"

# Run the chunk evaluation module using singularity with config variables
singularity exec --nv \
    --env INPUT_SOURCE="$INPUT_SOURCE" \
    --env INPUT_TYPE="$INPUT_TYPE" \
    --env PROMPT_TEMPLATE="$PROMPT_TEMPLATE" \
    --env OUTPUT_DESTINATION="$OUTPUT_DESTINATION" \
    --env OUTPUT_TYPE="$OUTPUT_TYPE" \
    --env SCORE_THRESHOLD="$SCORE_THRESHOLD" \
    --env MAX_CHUNK_SIZE="$MAX_CHUNK_SIZE" \
    --env LOCAL_JSON_PATH="$LOCAL_JSON_PATH" \
    --env LOGS_FOLDER="$LOGS_FOLDER" \
    --env OFFLINE_MODE="$OFFLINE_MODE" \
    container.sif /bin/bash /gpfs/projects/<project_id>/myfolder/scripts/slurm/run_chunk_evaluation.sh
EOF

echo "Submitting chunk evaluation job..."
echo "Configuration loaded from: $CONFIG_FILE"
echo "Account: $ACCOUNT"
echo "QOS: $QOS"

# Submit job
sbatch -A "$ACCOUNT" -q "$QOS" "$TMP_SLURM_SCRIPT"

# Clean up temporary script
rm "$TMP_SLURM_SCRIPT"
