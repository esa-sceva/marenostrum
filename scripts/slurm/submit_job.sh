#!/bin/bash

CONFIG_FILE="$1"

if [[ -z "$CONFIG_FILE" ]]; then
  echo "Usage: ./submit_job.sh <job_config.env>"
  exit 1
fi

# Load configuration
source "$CONFIG_FILE"

# Create a temporary SLURM script
TMP_SLURM_SCRIPT=$(mktemp)

cat <<EOF > "$TMP_SLURM_SCRIPT"
#!/bin/bash
#SBATCH --job-name=$JOB_NAME
#SBATCH -D .
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

singularity exec --nv container.sif /bin/bash /gpfs/projects/<project_id>/myfolder/run.sh "$VLLM_CONFIG" "$PIPELINE" "$OUTPUT_DIR"

echo "Job completed at \$(date)"
EOF

# Submit the job using account and QoS
sbatch -A "$ACCOUNT" -q "$QOS" "$TMP_SLURM_SCRIPT"
