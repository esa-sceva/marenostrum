#!/bin/bash
#SBATCH --job-name=test_synth_gen
#SBATCH -D .
#SBATCH --output=slurm_out/mpi_%j.out
#SBATCH --error=slurm_out/mpi_%j.err
#SBATCH --ntasks=2
#SBATCH --cpus-per-task=80
#SBATCH --time=00:15:00
#SBATCH --gres=gpu:4



vllm serve --config config1.yaml --port 8000 & # First vLLM server instance
vllm serve --config config2.yaml --port 8001 & # Second vLLM server instance

./run.sh --ports 8000,8001 # User process sending requests