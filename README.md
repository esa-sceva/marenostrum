# SATCOM Synthetic Data Generation on MareNostrum

This repository contains scripts and configurations for running synthetic data generation jobs on the MareNostrum HPC cluster using Singularity containers and SLURM job scheduling.

## Table of Contents

- [Overview](#overview)
- [Repository Structure](#repository-structure)
- [Prerequisites](#prerequisites)
- [Setup](#setup)
- [Running Jobs](#running-jobs)
- [Monitoring Jobs](#monitoring-jobs)
- [File Transfer](#file-transfer)
- [Quick Command Reference](#quick-command-reference)
- [Troubleshooting](#troubleshooting)
- [Additional Resources](#additional-resources)

## Overview

This repository provides **job configurations and scripts** to run synthetic data generation workloads on the MareNostrum HPC cluster. The actual synthetic data generation code is in the [satcom-synthetic-data-gen](https://github.com/esa-sceva/satcom-synthetic-data-gen) repository.

**This repository handles:**
- SLURM job configurations for MareNostrum
- Container setup and deployment
- Model download and management scripts
- File transfer workflows

**Technology Stack:**
- **MareNostrum 4/5**: BSC's HPC cluster
- **Singularity**: Containerization for reproducible environments
- **SLURM**: Job scheduling and resource management
- **vLLM**: High-performance LLM inference server
- **Multiple LLMs**: Llama, Mistral, Qwen models

**Related Repository:**
- [satcom-synthetic-data-gen](https://github.com/esa-sceva/satcom-synthetic-data-gen) - Core synthetic data generation code

## Repository Structure

```
satcom-marenostrum/
├── configs/
│   ├── slurm_jobs/                    # SLURM job configuration files
│   │   ├── llm_generation_vllm        # LLM generation with vLLM config
│   │   ├── chunk_evaluation           # Document chunk evaluation config
│   │   ├── evaluation                 # Q&A grading/evaluation config
│   │   └── template/                  # Template configurations
│   │       ├── multi_node             # Multi-node job template
│   │       └── single_node            # Single-node job template
│   │
│   └── vllm_configs/                  # vLLM server configurations
│       ├── llama3.3_70B.yaml          # Llama 3.3 70B config
│       ├── llama_3.yaml               # Llama 3 config
│       ├── mistral_large.yaml         # Mistral Large config
│       ├── mistral_small.yaml         # Mistral Small config
│       ├── qwen72B.yaml               # Qwen 72B config
│       └── qwen3.yaml                 # Qwen 3 config
│
├── scripts/
│   ├── huggingface/                   # HuggingFace model management
│   │   ├── download_hf_assets.py      # Download models and datasets
│   │   ├── deploy.sh                  # Deploy models to HPC
│   │   ├── hf_resources.yaml          # Model/dataset specifications
│   │   └── requirements.txt           # Python requirements
│   │
│   ├── singularity/                   # Container definitions
│   │   ├── definition_files/
│   │   │   └── satcom_synth_data_gen.def  # Singularity container definition
│   │   └── install_singularity.sh     # Singularity installation script
│   │
│   ├── slurm/                         # SLURM job scripts
│   │   ├── submit_llm_generation_vllm.sh  # Submit LLM generation jobs
│   │   ├── run_llm_generation_vllm.sh     # Run LLM generation with vLLM
│   │   ├── submit_evaluation.sh           # Submit Q&A grading jobs
│   │   ├── run_evaluation.sh              # Run Q&A grading
│   │   ├── submit_chunk_evaluation.sh     # Submit chunk evaluation jobs
│   │   ├── run_chunk_evaluation.sh        # Run chunk evaluation
│   │   ├── submit_job.sh                  # Generic job submission
│   │   ├── run.sh                         # Generic job runner
│   │   ├── test_submit.sh                 # Test job submission
│   │   └── slurm_submission               # SLURM submission template
│   │
│   └── slurm_multinode/               # Multi-node job scripts
│       ├── submit_multi_node_job.sh   # Submit multi-node jobs
│       ├── run_cluster.sh             # Run on cluster
│       ├── run.sh                     # Multi-node runner
│       └── check_GPUs.sh              # GPU availability checker
│
├── transfer/                          # Data transfer utilities
│   ├── README.md                      # Transfer utilities documentation
│   ├── transfer.sh                    # S3 → MareNostrum (interactive)
│   ├── transfer_to_s3.sh              # MareNostrum → S3 (optimized)
│   └── simple_move.sh                 # Move between folders on HPC
│
├── docs/                              # Documentation
│   ├── llm_generation_vllm_setup.md   # LLM generation setup guide
│   ├── chunk_evaluation_setup.md      # Chunk evaluation setup guide
│   └── evaluation_setup.md            # Q&A grading setup guide
│
├── .gitignore                         # Git ignore rules
├── COMMANDS.md                        # Quick command reference
└── README.md                          # This file
```

## Prerequisites

### Access Requirements

- **BSC Account**: Username and project allocation (e.g., `<hpc_username>`, project `<project_id>`)
- **SSH Access**: To `transfer1.bsc.es` (file transfer) and `alogin2.bsc.es` (job submission)
- **S3 Credentials**: For data storage (AWS S3 compatible)

### Software Requirements

- **Local Machine** (for container building):
  - WSL2 (Windows) or Linux
  - Singularity/Apptainer
  - dos2unix (for line ending conversion)
  
- **MareNostrum** (pre-installed):
  - Singularity
  - Python modules
  - CUDA/GPU drivers

## Setup

### 1. Singularity Container Setup

#### Build Container Locally (WSL/Linux)

```bash
# Install Singularity (if not already installed)
sudo apt-get install dos2unix
dos2unix ./scripts/singularity/install_singularity.sh
bash ./scripts/singularity/install_singularity.sh

# Build the container
singularity build --fakeroot container.sif ./scripts/singularity/definition_files/satcom_synth_data_gen.def

# Test the container locally
mkdir -p $HOME/projects/synthetic_output
chmod u+rwx $HOME/projects/synthetic_output
apptainer exec --bind $HOME/projects/synthetic_output:/workspace container.sif bash
```

#### Transfer Container to MareNostrum

```bash
# Transfer the built container
scp container.sif <hpc_username>@transfer1.bsc.es:/gpfs/projects/<project_id>/myfolder/

# Or transfer entire directory
scp -r . <hpc_username>@transfer1.bsc.es:/gpfs/projects/<project_id>/myfolder/
```


### 2. Configuring rclone

`rclone` is used for efficient file transfers between S3, local machines, and MareNostrum.

#### Setup S3 Remote

```bash
rclone config
# n) New remote
# Name: s3
# Storage: Amazon S3 (option 5)
# Provider: AWS S3 (option 1)
# Access Key ID: <your-aws-access-key>
# Secret Access Key: <your-aws-secret-key>
# Region: <your-region> (e.g., us-east-1)
# Leave other options as default
```

#### Setup BSC SFTP Remote

```bash
rclone config
# n) New remote
# Name: bsc
# Storage: SSH/SFTP (option 30+)
# Host: transfer1.bsc.es
# User: <hpc_username> (or your username)
# Port: 22
# Password: y (enter your password)
# Advanced config: n
```

#### Transfer Examples

```bash
# S3 to MareNostrum
rclone copy s3:<bucket-name>/path/ bsc:/gpfs/projects/<project_id>/myfolder/path/ --progress -vv

# MareNostrum to S3
rclone copy bsc:/gpfs/projects/<project_id>/myfolder/results/ s3:<bucket-name>/synthetic-data-gen/results/ --progress -vv --checksum

# Download sample dataset
rclone copy s3:<bucket-name>/sample-synthetic-data-gen/ bsc:/gpfs/projects/<project_id>/myfolder/sample_dataset --progress -vv
```

### 3. Model Download and Deployment

Models are downloaded via HuggingFace and transferred to MareNostrum through S3 or direct deployment.

#### Download Models on RunPod/Local Machine

```bash
# Clone the repository
git clone https://ghp_YOUR_TOKEN@github.com/esa-satcomllm/satcom-marenostrum.git
cd satcom-marenostrum

# Install requirements
cd scripts/huggingface
pip install -r requirements.txt

# Login to HuggingFace (if needed)
huggingface-cli login

# Edit hf_resources.yaml to specify models to download
# Then download
python scripts/huggingface/download_hf_assets.py scripts/huggingface/hf_resources.yaml
```

#### Transfer Models via S3

```bash
# Install AWS CLI (if not already installed)
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
apt-get update && apt-get install -y unzip curl
unzip awscliv2.zip
./aws/install

# Configure AWS
aws configure

# Upload to S3
aws s3 cp ./project/hf_cache s3://<bucket-name>/model_name_hfcache --recursive

# Download from S3 to MareNostrum using rclone (see next section)
rclone copy s3:<bucket-name>/model_name_hfcache/ bsc:/gpfs/projects/<project_id>/myfolder/model_name --progress -vv
```

#### Direct Deployment to MareNostrum

```bash
# Deploy from local machine
./scripts/huggingface/deploy.sh <local_path> <hpc_username> /gpfs/projects/<project_id>/myfolder/
```


## Running Jobs

This repository supports three main types of jobs for the synthetic data generation pipeline:

### 1. LLM Generation Jobs (vLLM)

Generate synthetic Q&A data using large language models with high-performance vLLM inference.

**Quick Start:**
```bash
# Edit configuration
nano configs/slurm_jobs/llm_generation_vllm

# Submit job
./scripts/slurm/submit_llm_generation_vllm.sh configs/slurm_jobs/llm_generation_vllm

# Monitor
squeue -u <hpc_username>
tail -f slurm_out_generation/*_vllm_*.out
```

**Supported Models:** Llama 3.3 70B, Mistral Large/Small, Qwen 72B  
**Resource Requirements:** 4 GPUs for 70B models, 2 GPUs for smaller models  

📖 **[Complete Guide: LLM Generation with vLLM](docs/llm_generation_vllm_setup.md)**

### 2. Chunk Evaluation Jobs

Chunk and score document chunks using reward models (UltraRM) to filter high-quality content.

**Quick Start:**
```bash
# Edit configuration
nano configs/slurm_jobs/chunk_evaluation

# Submit job
./scripts/slurm/submit_chunk_evaluation.sh configs/slurm_jobs/chunk_evaluation

# Monitor
squeue -u <hpc_username>
tail -f slurm_out/chunk_eval_*.out
```

**Purpose:** Pre-process documents, score quality, filter content  
**Resource Requirements:** 1 GPU, 20 CPUs  
**Typical Runtime:** 2-10 hours depending on dataset size

📖 **[Complete Guide: Chunk Evaluation](docs/chunk_evaluation_setup.md)**

### 3. Evaluation Jobs (Q&A Grading)

Use grading models to evaluate and score generated Q&A pairs during the synthetic data generation process.

**Quick Start:**
```bash
# Edit configuration
nano configs/slurm_jobs/evaluation

# Submit job
./scripts/slurm/submit_evaluation.sh configs/slurm_jobs/evaluation

# Monitor
squeue -u <hpc_username>
tail -f slurm_out/evaluation_*.out
```

**Purpose:** Grade Q&A quality using models (e.g., reward models, LLM-as-judge)  
**Resource Requirements:**  4 GPUs for 70B models, 2 GPUs for smaller models.

📖 **[Complete Guide: Evaluation Setup](docs/evaluation_setup.md)**


## Monitoring Jobs

### Check Job Status

```bash
# View all your jobs
squeue -u <hpc_username>

# View specific job
squeue -j <job_id>

# Detailed job information
scontrol show job <job_id>

# Cancel a job
scancel <job_id>
```

### View Job Logs

```bash
# Standard output
cat slurm_out/job_<job_id>.out
tail -f slurm_out/job_<job_id>.out

# Error output
cat slurm_out/job_<job_id>.err
tail -f slurm_out/job_<job_id>.err

# vLLM server logs (for generation jobs)
cat slurm_out_generation/job_<job_id>_vllm_server.log
tail -f slurm_out_generation/job_<job_id>_vllm_server.log
```

### Job Output Directories

- `slurm_out/`: Standard job logs
- `slurm_out_generation/`: LLM generation job logs (including vLLM server logs)
- `results/`: Generated synthetic data
- `chunks/`: Evaluated document chunks
- `logs/`: Processing logs from chunk evaluation
- `gpu_logs/`: GPU utilization logs

## File Transfer

### SCP (Single Files/Directories)

```bash
# Upload single file
scp file.txt <hpc_username>@transfer1.bsc.es:/gpfs/projects/<project_id>/myfolder/

# Upload directory
scp -r . <hpc_username>@transfer1.bsc.es:/gpfs/projects/<project_id>/myfolder/
```

### rclone (Recommended for Large Transfers)

```bash
# MareNostrum → S3
rclone copy bsc:/gpfs/projects/<project_id>/myfolder/results/ s3:<bucket-name>/synthetic-data-gen/results/ --progress -vv

# S3 → MareNostrum
rclone copy s3:<bucket-name>/data/ bsc:/gpfs/projects/<project_id>/myfolder/data/ --progress -vv
```

### Transfer Utility Scripts

This repository includes helper scripts in the `transfer/` directory for common transfer operations:

- **`transfer.sh`**: Download files from S3 to MareNostrum (interactive, with folder selection)
- **`transfer_to_s3.sh`**: Upload results from MareNostrum to S3 (optimized for large transfers)
- **`simple_move.sh`**: Move data between folders on MareNostrum

See **[transfer/README.md](transfer/README.md)** for detailed usage instructions.


## Quick Command Reference

For a comprehensive list of commands, see **[COMMANDS.md](COMMANDS.md)**

### Essential Commands

```bash
# Submit jobs
./scripts/slurm/submit_llm_generation_vllm.sh configs/slurm_jobs/llm_generation_vllm
./scripts/slurm/submit_chunk_evaluation.sh configs/slurm_jobs/chunk_evaluation
./scripts/slurm/submit_evaluation.sh configs/slurm_jobs/evaluation

# Monitor jobs
squeue -u <hpc_username>
tail -f slurm_out/job_<id>.err

# Transfer files
scp -r . <hpc_username>@transfer1.bsc.es:/gpfs/projects/<project_id>/myfolder/
rclone copy bsc:/gpfs/projects/<project_id>/myfolder/results/ s3:<bucket-name>/ --progress -vv

# Fix line endings (Windows)
sed -i 's/\r$//' configs/slurm_jobs/*
sed -i 's/\r$//' scripts/slurm/*.sh
```

## Troubleshooting

### Job Won't Start

1. **Check queue status**: `squeue -u $USER`
2. **Check account balance**: Ensure your project has available hours
3. **Verify QoS**: Use `acc_debug` for quick testing (limited resources)

### Container Issues

```bash
# Test container interactively
singularity shell --nv container.sif

# Check if paths are accessible
singularity exec container.sif ls /gpfs/projects/<project_id>/myfolder/
```

### Model Not Found

1. **Verify model path**: Check that the model exists at the specified path
2. **Check HF_HOME**: Ensure `HF_HOME` is set correctly in the run script
3. **Offline mode**: If OFFLINE_MODE=1, ensure model is fully cached

```bash
# Find model files
find /gpfs/projects/<project_id>/myfolder/ -name "config.json" | head -10
```

### vLLM Server Won't Start

1. **Check GPU allocation**: Ensure GRES matches tensor-parallel-size
2. **View vLLM logs**: `tail -f slurm_out_generation/*_vllm_server.log`
3. **Check GPU availability**: `nvidia-smi` (in job allocation)



## Credentials Reference

**Connection Details:**
- **Username**: <hpc_username>
- **Password**: <hpc_username>
- **Project**: <project_id>
- **Transfer Node**: ssh <hpc_username>@transfer2.bsc.es
- **Login Node**: ssh <hpc_username>@alogin2.bsc.es
- **Working Directory**: /gpfs/projects/<project_id>/satcom

**Important Notes:**
- Use `transfer1.bsc.es` or `transfer2.bsc.es` for file transfers
- Use `alogin1.bsc.es` or `alogin2.bsc.es` for job submission
- Never run computations on login nodes - always submit SLURM jobs
- Use scratch space `/gpfs/scratch/<project_id>/` for temporary/intermediate files
- Project space `/gpfs/projects/<project_id>/` for long-term storage

## Additional Resources

### Documentation

- [Complete LLM Generation Guide](docs/llm_generation_vllm_setup.md) - Generate Q&A pairs
- [Complete Chunk Evaluation Guide](docs/chunk_evaluation_setup.md) - Preprocess documents
- [Complete Q&A Grading Guide](docs/evaluation_setup.md) - Grade Q&A quality
- [Quick Command Reference](COMMANDS.md) - Essential commands

### Related Repositories

- [satcom-synthetic-data-gen](https://github.com/esa-sceva/satcom-synthetic-data-gen) - Core synthetic data generation code

### External Resources

- [MareNostrum User Guide](https://www.bsc.es/user-support/mn4.php)
- [SLURM Documentation](https://slurm.schedmd.com/documentation.html)
- [Singularity Documentation](https://sylabs.io/docs/)
- [vLLM Documentation](https://docs.vllm.ai/)


---


