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
2. Run the slurm script changing the `qos` and the script `slurm_submission`
```bash
sbatch -A, --account=ehpc190 -q, --qos=acc_debug slurm_submission 
```
3. You will find the stderr and the stdout in the `slurm_out/<job_id>.[out/err]` file.

If you want to run your own script create a bash script following the example in `scripts/singularity/run.sh`