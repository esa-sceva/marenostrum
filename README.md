# Marenostrum


## Download huggingface assets
Use `huggingface/download_hf_assets.py` to download huggingface assets. Follow the sample configuration provided and add the model and the dataset you want to download.

```bash

python scripts/huggingface/download_hf_assets.py scripts/huggingface/hf_resources.yaml

```

After the download use the `scripts/huggingface/deploy.sh` to deploy the models to the `marenostrum` directory.

```bash
./scripts/huggingface/deploy.sh <local_path> <marenostrum user> [remote_path]
```

## Run a job 
To make a run follow the following steps:
1.  Cd in the project root directory 
```bash
cd /gpfs/projects/<project_id>/satcom
```
2. Create a configuration file for setting up slurm directives and job-specific argument as this:
```bash
# SLURM directives
JOB_NAME=test_synth_gen
WORK_DIR=.
OUT_FILE=slurm_out/mpi_%j.out
ERR_FILE=slurm_out/mpi_%j.err
NTASKS=2
CPUS_PER_TASK=40 # 20 CPU for each GPU used
TIME=00:50:00
GRES=gpu:2       # Number of GPUs to use

# SLURM submission options
ACCOUNT=ehpc190
QOS=acc_debug

# Job-specific arguments
VLLM_CONFIG=./configs/vllm_configs/mistral_small.yaml
PIPELINE=./configs/pipelines/single_hop_qa_w_bonus.yaml
OUTPUT_DIR=./out/single_hop_qa_w_bonus
```
3. Create a vLLM config file:
```yaml
# config.yaml

model: /gpfs/projects/<project_id>/myfolder/hf_cache/models/models--mistralai--Mistral-Small-3.2-24B-Instruct-2506/snapshots/46a27874d7f7a7b38344124d32a7a3c4589d3b53
port: 8000
uvicorn-log-level: "info"
dtype: "bfloat16"
served-model-name: "mistral_small"
tokenizer_mode: mistral
config_format: mistral
load_format: mistral
tool-call-parser: mistral
enable-auto-tool-choice: true
tensor-parallel-size: 2
```

4. Run the script with the selected configuration file:
```bash
./scripts/slurm/submit_job.sh <config_file>
```
5. You will find the stderr and the stdout in the `slurm_out/<job_id>.[out/err]` file.

If you want to run your own script create a bash script following the example in `scripts/singularity/run.sh`