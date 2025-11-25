# Quick Command Reference for MareNostrum

This repository provides job configurations and scripts for running synthetic data generation workloads on MareNostrum HPC. The actual generation code is in [satcom-synthetic-data-gen](https://github.com/esa-sceva/satcom-synthetic-data-gen).

## Access & Connection

### SSH Access

```bash
# File Transfer Node
ssh <hpc_username>@transfer1.bsc.es

# Login Node (Job Submission)
ssh <hpc_username>@alogin1.bsc.es

# Working Directory
cd /gpfs/projects/<project_id>/satcom
```

## File Transfer

### SCP (Single Files)

```bash
# Upload single file
scp local_file.txt <hpc_username>@transfer1.bsc.es:/gpfs/projects/<project_id>/myfolder/

# Upload directory
scp -r local_directory/ <hpc_username>@transfer1.bsc.es:/gpfs/projects/<project_id>/myfolder/

# Download file
scp <hpc_username>@transfer1.bsc.es:/gpfs/projects/<project_id>/myfolder/results/output.jsonl ./

# Upload specific config files
scp configs/slurm_jobs/chunk_evaluation <hpc_username>@transfer1.bsc.es:/gpfs/projects/<project_id>/myfolder/configs/slurm_jobs/
scp scripts/slurm/run_chunk_evaluation.sh <hpc_username>@transfer1.bsc.es:/gpfs/projects/<project_id>/myfolder/scripts/slurm/
scp scripts/slurm/submit_chunk_evaluation.sh <hpc_username>@transfer1.bsc.es:/gpfs/projects/<project_id>/myfolder/scripts/slurm/
```

### rclone (Large Transfers)

```bash
# S3 to MareNostrum
rclone copy s3:<bucket-name>/path/ bsc:/gpfs/projects/<project_id>/myfolder/path/ --progress -vv

# MareNostrum to S3
rclone copy bsc:/gpfs/projects/<project_id>/myfolder/results/ s3:<bucket-name>/synthetic-data-gen/results/ --progress -vv --checksum

# Specific examples
rclone copy s3:<bucket-name>/qwen25_72B_hfcache/ bsc:/gpfs/projects/<project_id>/myfolder/qwen_72B --progress -vv
rclone copy s3:<bucket-name>/sample-synthetic-data-gen/ bsc:/gpfs/projects/<project_id>/myfolder/sample_dataset --progress -vv
rclone copy bsc:/gpfs/projects/<project_id>/myfolder/grades/ s3:<bucket-name>/synthetic-data-gen/grades/ --progress -vv
rclone copy bsc:/gpfs/projects/<project_id>/myfolder/questions/arxiv_1.jsonl s3:<bucket-name>/synthetic-data-gen/dataset/questions/ --progress -vv
```

## Job Management

### Submit Jobs

```bash
# LLM Generation with vLLM
./scripts/slurm/submit_llm_generation_vllm.sh configs/slurm_jobs/llm_generation_vllm

# Chunk Evaluation
./scripts/slurm/submit_chunk_evaluation.sh configs/slurm_jobs/chunk_evaluation

# Evaluation (Quality Assessment)
./scripts/slurm/submit_evaluation.sh configs/slurm_jobs/evaluation

# Generic job submission
./scripts/slurm/submit_job.sh configs/slurm_jobs/your_config
```

### Monitor Jobs

```bash
# Check all your jobs
squeue -u <hpc_username>

# Check specific job
squeue -j <job_id>

# Detailed job information
scontrol show job <job_id>

# Cancel job
scancel <job_id>

# Cancel all your jobs
scancel -u <hpc_username>
```

### View Logs

```bash
# Standard output
cat slurm_out/mpi_<job_id>.out
tail -f slurm_out/mpi_<job_id>.out

# Error output
cat slurm_out/mpi_<job_id>.err
tail -f slurm_out/mpi_<job_id>.err

# Generation job logs
tail -f slurm_out_generation/llama33_70b_vllm_<job_id>.err
cat slurm_out_generation/llama33_70b_vllm_<job_id>_vllm_server.log

# Last 50 lines of error log
tail -n 50 slurm_out/mpi_<job_id>.err
```

## File Management

### Count Files

```bash
# Count files in current directory
ls -1 | wc -l

# Count all files recursively
find chunks/ -type f | wc -l

# Count lines in JSONL file
wc -l data.jsonl
```

### Disk Usage

```bash
# Size of directory
du -sh /gpfs/projects/<project_id>/myfolder/

# Size with depth limit
du -h --max-depth=1 data/

# Detailed folder statistics
for d in data/*/ ; do
    echo -n "$(du -sh "$d" | cut -f1)  "
    echo -n "$(find "$d" -type f | wc -l) files  "
    echo "$d"
done
```

### Move/Copy Files

```bash
# Move files to scratch
mv * /gpfs/scratch/<project_id>/myfolder/synth-data-gen/logs/

# Copy directory
cp -r source_dir/ destination_dir/

# Create directory
mkdir -p /gpfs/projects/<project_id>/myfolder/new_folder
```

## Container Management

### Build Container (WSL/Local)

```bash
# Install Singularity
sudo apt-get install dos2unix
dos2unix ./scripts/singularity/install_singularity.sh
bash ./scripts/singularity/install_singularity.sh

# Build container
singularity build --fakeroot container.sif ./scripts/singularity/definition_files/satcom_synth_data_gen.def

# Transfer to MareNostrum
scp container.sif <hpc_username>@transfer1.bsc.es:/gpfs/projects/<project_id>/myfolder/
```

### Test Container

```bash
# Interactive shell
singularity shell --nv container.sif

# Execute command
singularity exec --nv container.sif python --version

# With bind mount
singularity exec --bind $HOME/projects/synthetic_output:/workspace container.sif bash
```

## Model Management

### Download Models (RunPod/Local)

```bash
# Clone repository
git clone https://<GITHUB_TOKEN>"@github.com/esa-satcomllm/satcom-marenostrum.git
cd satcom-marenostrum

# Install requirements
cd scripts/huggingface
pip install -r requirements.txt

# Login to HuggingFace (if needed)
huggingface-cli login

# Download models (edit hf_resources.yaml first)
python scripts/huggingface/download_hf_assets.py scripts/huggingface/hf_resources.yaml
```

### Transfer Models via S3

```bash
# Install AWS CLI
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
apt-get update && apt-get install -y unzip curl
unzip awscliv2.zip
./aws/install

# Configure AWS
aws configure

# Upload to S3
aws s3 cp ./project/hf_cache s3://<bucket-name>/model_name_hfcache --recursive

# Download to MareNostrum (use rclone)
rclone copy s3:<bucket-name>/model_name_hfcache/ bsc:/gpfs/projects/<project_id>/myfolder/model_name --progress -vv
```



## Troubleshooting

### Fix Line Endings (Windows → Linux)

```bash
sed -i 's/\r$//' configs/slurm_jobs/chunk_evaluation
sed -i 's/\r$//' scripts/slurm/run_chunk_evaluation.sh
sed -i 's/\r$//' scripts/slurm/submit_chunk_evaluation.sh
```

### Fix Permissions

```bash
# Make scripts executable
chmod +x scripts/slurm/*.sh
chmod +x scripts/huggingface/*.sh

# Fix directory permissions
chmod u+rwx $HOME/projects/synthetic_output
```

### Check System

```bash
# Load modules
module load singularity
module load python

# Check GPU (in job)
nvidia-smi

# Check disk quota
bsc_quota  # BSC-specific quota command

# Check computation hours usage
bsc_acct   # BSC account usage (GPU hours, etc.)

# Check available resources
sinfo
```

## Module Loading

```bash
# Load Python module
module load python

# List available modules
module avail

# List loaded modules
module list

# Unload module
module unload python
```


## Quick Workflows

### Deploy New Job Config

```bash
# 1. Edit config locally
nano configs/slurm_jobs/my_job

# 2. Upload to MareNostrum
scp configs/slurm_jobs/my_job <hpc_username>@transfer1.bsc.es:/gpfs/projects/<project_id>/myfolder/configs/slurm_jobs/

# 3. SSH to login node
ssh <hpc_username>@alogin2.bsc.es
cd /gpfs/projects/<project_id>/satcom

# 4. Fix line endings if needed
sed -i 's/\r$//' configs/slurm_jobs/my_job

# 5. Submit job
./scripts/slurm/submit_job.sh configs/slurm_jobs/my_job

# 6. Monitor
squeue -u <hpc_username>
tail -f slurm_out/mpi_*.err
```

### Collect Results

```bash
# 1. Check job completed
squeue -u <hpc_username>

# 2. Verify output
ls -lh /gpfs/projects/<project_id>/myfolder/results/

# 3. Transfer to S3
rclone copy bsc:/gpfs/projects/<project_id>/myfolder/results/ s3:<bucket-name>/synthetic-data-gen/results/ --progress -vv --checksum

# 4. Or download locally
scp -r <hpc_username>@transfer1.bsc.es:/gpfs/projects/<project_id>/myfolder/results/ ./local_results/
```




## Detailed Guides

For comprehensive setup and usage instructions, see:

- [Main README](README.md) - Overview and setup
- [LLM Generation Guide](docs/llm_generation_vllm_setup.md) - Generate Q&A pairs with vLLM
- [Chunk Evaluation Guide](docs/chunk_evaluation_setup.md) - Document preprocessing
- [Q&A Grading Guide](docs/evaluation_setup.md) - Grade Q&A quality

## Related Repositories

- 🔗 [satcom-synthetic-data-gen](https://github.com/esa-sceva/satcom-synthetic-data-gen) - Core synthetic data generation code

## Contact & Support

- **BSC Support**: https://www.bsc.es/user-support
- **SLURM Documentation**: https://slurm.schedmd.com/
- **Project Team**: https://github.com/esa-sceva

