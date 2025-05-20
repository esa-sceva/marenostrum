import os
import json
import subprocess
from datasets import load_dataset


def save_as_jsonl(dataset, output_path):
    """Save dataset to JSONL format."""
    os.makedirs(os.path.dirname(output_path), exist_ok=True)
    with open(output_path, 'w', encoding='utf-8') as f:
        for item in dataset:
            f.write(json.dumps(item) + '\n')
    print(f"Saved JSONL to {output_path}")


def upload_file_scp(local_path, remote_user, remote_host, remote_path):
    """Upload a file to remote server using scp."""
    remote_full_path = f"{remote_user}@{remote_host}:{remote_path}"
    try:
        subprocess.run(["scp", local_path, remote_full_path], check=True)
        print(f"Uploaded {local_path} to {remote_full_path}")
    except subprocess.CalledProcessError as e:
        print("Error during SCP upload:", e)


def main(username, remote_host, remote_dir):
    # Configurations
    dataset_name = "ag_news"  # or any other HF dataset like "imdb", "squad"
    split = "train"  # or "test", "validation"
    jsonl_path = f"/tmp/{dataset_name}_{split}.jsonl"

    # Remote server details
    remote_user = "your.username"
    remote_host = "your.remote.server"
    remote_dir = "/remote/path/on/server"

    # Load dataset
    dataset = load_dataset(dataset_name, split=split)
    print(f"Loaded dataset '{dataset_name}' with {len(dataset)} rows")

    # Save as JSONL
    save_as_jsonl(dataset, jsonl_path)

    # Upload via SCP
    upload_file_scp(jsonl_path, remote_user, remote_host, remote_dir)


if __name__ == "__main__":
    main()
