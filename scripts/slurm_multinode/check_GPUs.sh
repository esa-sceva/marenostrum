#!/bin/bash

echo "Checking GPUs in all nodes..."
nodes=$(scontrol show hostnames "$SLURM_JOB_NODELIST")
for NODE in $nodes; do
    echo "Checking $NODE..."
    if srun --nodes=1 --ntasks=1 -w "$NODE" nvidia-smi -q -d ECC | grep -q 'Double Bit ECC Errors.*[1-9]'; then
        echo "false"
        exit 1
    fi
done

echo "true"
exit 0
