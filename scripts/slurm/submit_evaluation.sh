#!/bin/bash

CONFIG_FILE="$1"
if [[ -z "$CONFIG_FILE" ]]; then
  echo "Usage: ./submit_evaluation.sh <job_config>"
  echo "Example: ./submit_evaluation.sh configs/slurm_jobs/evaluation"
  exit 1
fi

# Load job configuration
source "$CONFIG_FILE"

# Create output directories
mkdir -p "$(dirname "$OUT_FILE")"
mkdir -p "$(dirname "$ERR_FILE")"
mkdir -p "$(dirname "$RESULTS_PATH")"
mkdir -p "$(dirname "$OUTPUT_PATH")"

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

echo "Running Qwen2.5 72B Evaluation with vLLM:"
echo "- Dataset path: $DATASET_PATH"
echo "- Results path: $RESULTS_PATH"
echo "- Output path: $OUTPUT_PATH"
echo "- Model: $MODEL_NAME"
echo "- Backend: $BACKEND (vLLM)"
echo "- Workers: $NUM_WORKERS"
echo "- Threshold: $THRESHOLD"

# Export ALL config variables so they're available in singularity
export MODEL_NAME="$MODEL_NAME"
export DATASET_PATH="$DATASET_PATH"
export RESULTS_PATH="$RESULTS_PATH"
export OUTPUT_PATH="$OUTPUT_PATH"
export PROMPT_PATH="$PROMPT_PATH"
export THRESHOLD="$THRESHOLD"
export PERTINENCE_THRESHOLD="$PERTINENCE_THRESHOLD"
export CONTEXTUAL_RELEVANCE_THRESHOLD="$CONTEXTUAL_RELEVANCE_THRESHOLD"
export CORRECTNESS_THRESHOLD="$CORRECTNESS_THRESHOLD"
export FILTER_LOGIC="$FILTER_LOGIC"
export N_DOCS="$N_DOCS"
export N_SHOTS="$N_SHOTS"
export TEMPERATURE="$TEMPERATURE"
export BACKEND="$BACKEND"
export NUM_WORKERS="$NUM_WORKERS"
export VLLM_LOG_FILE="slurm_out_evaluation/qwen2.5_72b_eval_\${SLURM_JOB_ID}_vllm_server.log"

# Run the Qwen2.5 72B evaluation vLLM job using singularity
singularity exec --nv container.sif /bin/bash /gpfs/projects/<project_id>/myfolder/scripts/slurm/run_evaluation.sh
EOF

echo "Submitting Qwen2.5 72B Evaluation vLLM job..."
echo "Configuration loaded from: $CONFIG_FILE"
echo "Account: $ACCOUNT"
echo "QOS: $QOS"

# Submit job
sbatch -A "$ACCOUNT" -q "$QOS" "$TMP_SLURM_SCRIPT"

# Clean up temporary script
rm "$TMP_SLURM_SCRIPT"
