

import os
import subprocess

models = [
    {
        'model_name': 'mistral_large',
        'shards': [i for i in range(1, 3)],
        'task': 'qa',
        'served_model': 'Mistral-Large-Instruct-2411',
        'slurm_template': './configs/slurm_jobs/template/multi_node',
        'pipeline_template': './configs/pipelines/template/qa.yaml',
        'vllm_config': './configs/vllm_configs/mistral_large.yaml'

    },
    {
        'model_name': 'mistral_large',
        'shards': [i for i in range(1, 3)],
        'task': 'refusal_qa',
        'served_model': 'Mistral-Large-Instruct-2411',
        'slurm_template': './configs/slurm_jobs/template/multi_node',
        'pipeline_template': './configs/pipelines/template/refusal_qa.yaml',
        'vllm_config': './configs/vllm_configs/mistral_large.yaml'

    },
    {
        'model_name': 'mistral_large',
        'shards': [i for i in range(1, 3)],
        'task': 'summarization',
        'served_model': 'Mistral-Large-Instruct-2411',
        'slurm_template': './configs/slurm_jobs/template/multi_node',
        'pipeline_template': './configs/pipelines/template/summarization.yaml',
        'vllm_config': './configs/vllm_configs/mistral_large.yaml'

    },
]

def format_pipeline(pipeline_template, served_model, data_path):
    # Load the pipeline template
    with open(pipeline_template, 'r') as file:
        pipeline = file.read()
    # Replace placeholders with actual values
    pipeline = pipeline.replace('$MODEL', served_model)
    pipeline = pipeline.replace('$DATA_PATH', data_path)
    return pipeline

import subprocess
import getpass

def job_is_running(job_name):
    try:
        user = getpass.getuser()
        result = subprocess.run(
            ["squeue", "--name", job_name, "-u", user],
            capture_output=True,
            text=True,
            check=True
        )
        return len(result.stdout.strip().splitlines()) > 1  # Header + at least one job
    except subprocess.CalledProcessError as e:
        print(f"Error checking squeue: {e}")
        return False


def format_slurm(slurm_template, vllm_config, pipeline_path, run_name, model_name, task):
    # Load the SLURM template
    with open(slurm_template, 'r') as file:
        slurm = file.read()
    #
    output_dir = './out_prod/' + f'{model_name}/{task}/' + run_name
    # Create output directory if it doesn't exist
    os.makedirs(output_dir, exist_ok=True)

    # Replace placeholders with actual values
    slurm = slurm.replace('VLLM_CONFIG=', f'VLLM_CONFIG={vllm_config}')
    slurm = slurm.replace('PIPELINE=', f'PIPELINE={pipeline_path}')
    slurm = slurm.replace('OUTPUT_DIR=', f'OUTPUT_DIR={output_dir}')
    slurm = slurm.replace('JOB_NAME=', f"JOB_NAME={run_name}")

    # Replace log dir
    log_dir = './slurm_out_prod/' + f'{model_name}/{task}'
    os.makedirs(log_dir, exist_ok=True)

    print(log_dir)

    slurm = slurm.replace('OUT_FILE=', f"OUT_FILE={log_dir}/mpi_%x_%j.out")
    slurm = slurm.replace('ERR_FILE=', f"ERR_FILE={log_dir}/mpi_%x_%j.err")
    return slurm

def run_slurm_job(job_name, slurm_path, is_multinode:bool):
    # Check if the JOB_NAME is already running
    if job_is_running(job_name):
        print(f"Job {job_name} is already running.")
        return
    # Submit the SLURM job
    if is_multinode:
        print('Submitting multi-node job...')
        os.system(f'./scripts/slurm_multinode/submit_multi_node_job.sh {slurm_path}')
    else:
        print('Submitting single node job...')
        os.system(f'./scripts/slurm/submit_job.sh {slurm_path}')


def run_jobs():
    for model in models:
        for shard in model['shards']:
            print(f"Running job for model {model['model_name']} on shard {shard}...")
            task = model['task']
            model_name = model['model_name']
            run_name = f"{model_name}_{task}_{shard}"
            data_path = f"/gpfs/projects/<project_id>/myfolder/corpus_pii/corpus_pii_split_{shard}.jsonl"

            pipeline = format_pipeline(model['pipeline_template'], model['served_model'], data_path)


            pipeline_tmp_path = f"./pipelines_tmp/{model_name}/{task}"
            slurm_tmp_path = f"./slurm_tmp/{model_name}/{task}"
            # Create tmp directories where the pipeline and slurm scripts will be stored
            os.makedirs(pipeline_tmp_path, exist_ok=True)
            os.makedirs(slurm_tmp_path, exist_ok=True)

            # Save the pipeline and SLURM script to temporary directories
            pipeline_tmp_file = f"{pipeline_tmp_path}/{run_name}.yaml"
            with open(pipeline_tmp_file, 'w') as file:
                file.write(pipeline)

            slurm_script = format_slurm(model['slurm_template'], model['vllm_config'], pipeline_tmp_file, run_name, model_name, task)
            slurm_script_tmp_file = f"{slurm_tmp_path}/{run_name}"
            with open(slurm_script_tmp_file, 'w') as file:
                file.write(slurm_script)
            # Submit the SLURM job
            run_slurm_job(run_name, slurm_script_tmp_file, is_multinode=model['slurm_template'].endswith('multi_node'))


def main():
    run_jobs()


if __name__ == '__main__':
    main()