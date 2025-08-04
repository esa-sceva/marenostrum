#!/bin/bash

CONFIG_FILE="$1"
if [[ -z "$CONFIG_FILE" ]]; then
  echo "Usage: ./submit_job.sh <job_config.env>"
  exit 1
fi

# Load job configuration
source "$CONFIG_FILE"

# Prompt for checkpoint if available
CHECKPOINT_ID=""
CHECKPOINT_DIR="${OUTPUT_DIR}/checkpoints"
if [[ -d "$CHECKPOINT_DIR" ]]; then
    CHECKPOINTS=($(ls "$CHECKPOINT_DIR"/checkpoint_*.json 2>/dev/null | sed -E 's/.*checkpoint_([0-9]+)\.json/\1/' | sort -n))
    if [[ ${#CHECKPOINTS[@]} -gt 0 ]]; then
        echo "Available checkpoints in $CHECKPOINT_DIR:"
        for ckpt in "${CHECKPOINTS[@]}"; do
            echo "  - checkpoint ID: $ckpt"
        done
        echo -n "Enter checkpoint ID to resume from (or leave blank to start fresh): "
        read USER_CKPT

        if [[ -n "$USER_CKPT" ]]; then
            if [[ " ${CHECKPOINTS[@]} " =~ " ${USER_CKPT} " ]]; then
                CHECKPOINT_ID="$USER_CKPT"
                echo "Resuming from checkpoint $CHECKPOINT_ID"
            else
                echo "❌ Error: Checkpoint ID '$USER_CKPT' is not valid."
                exit 1
            fi
        else
            echo "No checkpoint selected. Starting fresh."
        fi
    fi
fi

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

echo "Running with:"
echo "- VLLM config: $VLLM_CONFIG"
echo "- Pipeline: $PIPELINE"
echo "- Output dir: $OUTPUT_DIR"
echo "- Checkpoint ID: ${CHECKPOINT_ID:-none}"
echo "- Max samples: ${MAX_SAMPLES:-∞}"


singularity exec --nv mistral_gen.sif /bin/bash /gpfs/projects/<project_id>/myfolder/scripts/slurm/run.sh $VLLM_CONFIG "$PIPELINE" "$OUTPUT_DIR" "${CHECKPOINT_ID:-}"
EOF

# Submit job
sbatch -A "$ACCOUNT" -q "$QOS" "$TMP_SLURM_SCRIPT"
