#!/bin/bash

#SBATCH --job-name=test_multi_node
#SBATCH --nodes=2
#SBATCH --gres=gpu:4
#SBATCH --tasks-per-node=1
#SBATCH --cpus-per-task=80
#SBATCH --time=02:00:00
#SBATCH --output=ray-cluster-%j.out
#SBATCH --error=ray-cluster-%j.err
#SBATCH --account=ehpc190
#SBATCH --qos=acc_ehpc


CONFIG_FILE="$1"
if [[ -z "$CONFIG_FILE" ]]; then
  echo "Usage: ./submit_job.sh <job_config.env>"
  exit 1
fi

# Load job configuration
source "$CONFIG_FILE"



IMAGE=/apps/ACC/VLLM/EXAMPLES/SINGULARITY/IMAGES/vllm-0.8.3.sif
MODEL_PATH="/gpfs/scratch/<project_id>/myfolder/hf_cache/models/models--mistralai--Mistral-Large-Instruct-2407/snapshots/39ae65a130671df1ce97c50111dc68706ec12d6f"
HUGGINGFACE_HOME="/gpfs/scratch/<project_id>/myfolder/hf_cache/"


# Check GPUs before proceeding
if ./check_GPUs.sh; then
    echo "GPUs are operational. Proceeding with the setup..."
else
    echo "GPUs are not operational. Exiting."
    exit 1
fi

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



# Load modules
module load singularity


# Export variables
export SRUN_CPUS_PER_TASK=${SLURM_CPUS_PER_TASK}

# NCCL variables
export NCCL_NET=IB
export NCCL_SOCKET_IFNAME=ib0,ib1,ib2,ib3
export NCCL_IB_HCA=mlx5_0,mlx5_1,mlx5_4,mlx5_5
export NCCL_DEBUG=TRACE
export NCCL_NVLS_ENABLE=0
export NCCL_IB_DISABLE=0

# Ray variables
export RAY_OBJECT_STORE_ALLOW_SLOW_STORAGE=1
export RAY_USAGE_STATS_ENABLED=1


# Get current hostnames and Head Node
nodes=$(scontrol show hostnames "$SLURM_JOB_NODELIST")
nodes_array=($nodes)
head_node=${nodes_array[0]}
head_node_ip=$(srun --nodes=1 --ntasks=1 -w "$head_node" hostname --ip-address)

# Head the head_node_ip and port
port=6379
ip_head=$head_node_ip:$port
export ip_head


# Start the Head Node, wait until all ray cluster is initialized.
echo "Starting HEAD at $head_node"
export VLLM_HOST_IP=$head_node_ip
srun -n 1 --nodes=1 --gres=gpu:4 -c 80 --cpu-bind=none  -w "$head_node" --export=ALL,VLLM_HOST_IP=$head_node_ip bash run_cluster.sh $IMAGE $head_node_ip --head $HUGGINGFACE_HOME &
sleep 30


# Start Ray cluster on worker nodes
worker_num=$((SLURM_NNODES - 1))
for ((i = 1; i <= worker_num; i++)); do
    node_i=${nodes_array[$i]}
    echo "Starting WORKER $i at $node_i"
    local_node_ip=$(srun -n 1 -N 1 -c 1 -w "$node_i" hostname --ip-address)
    export VLLM_HOST_IP=$local_node_ip
    ip_local=$local_node_ip:$port
    srun -n 1 --nodes=1 --gres=gpu:4 -c 80 --cpu-bind=none -w "$node_i" --export=ALL,VLLM_HOST_IP=$local_node_ip bash run_cluster.sh $IMAGE $head_node_ip --worker $HUGGINGFACE_HOME &
    sleep 3
done

sleep 120
echo "Starting RUN at $head_node"
export VLLM_HOST_IP=$head_node_ip


# Once the ray cluster is initialized, Serve vLLM Model using singularity image.
singularity run --nv $IMAGE --model $MODEL_PATH ls--tokenizer_mode mistral --config_format mistral --load_format mistral --tensor_parallel_size 8 --served_model_name mistral_large  --swap-space 2 --cpu-offload-gb 0.5 --enable-chunked-prefill --enforce-eager --distributed-executor-backend=ray &


singularity exec mistral_gen.sif /bin/bash /gpfs/projects/<project_id>/myfolder/scripts/slurm_multinode/run.sh "$PIPELINE" "$OUTPUT_DIR" "${CHECKPOINT_ID:-}"
