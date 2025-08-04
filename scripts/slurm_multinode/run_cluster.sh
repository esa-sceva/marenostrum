#!/bin/bash

# Check for minimum number of required arguments
if [ $# -lt 4 ]; then
    echo "Usage: $0 singularity_image head_node_address --head|--worker path_to_hf_home [additional_args...]"
    exit 1
fi

# Assign the first three arguments and shift them away
SINGULARITY_IMAGE="$1"
HEAD_NODE_ADDRESS="$2"
NODE_TYPE="$3"  # Should be --head or --worker
PATH_TO_HF_HOME="$4"
shift 4

# Additional arguments are passed directly to the Docker command
ADDITIONAL_ARGS=("$@")

# Validate node type
if [ "${NODE_TYPE}" != "--head" ] && [ "${NODE_TYPE}" != "--worker" ]; then
    echo "Error: Node type must be --head or --worker"
    exit 1
fi


echo "Starting node $NODE_TYPE"

# Command setup for head or worker node
RAY_START_CMD="ray start --block"
if [ "${NODE_TYPE}" == "--head" ]; then
    RAY_START_CMD+=" --head --port=6379 --num-cpus 80 --num-gpus 4 --node-ip-address=${HEAD_NODE_ADDRESS}"
else
    RAY_START_CMD+=" --address=${HEAD_NODE_ADDRESS}:6379 --num-cpus 80 --num-gpus 4"
fi

export RAY_USAGE_STATS_ENABLED=1

singularity exec \
    --network host \
    --nv \
    -B "${PATH_TO_HF_HOME}:/root/.cache/huggingface" \
    --env RAY_USAGE_STATS_ENABLED=1 \
    ${SINGULARITY_IMAGE} ${RAY_START_CMD}


