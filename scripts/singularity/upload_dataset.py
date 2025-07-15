import os
import json
import subprocess
from datasets import load_dataset
import dotenv
import click

dotenv.load_dotenv()


def save_as_jsonl(dataset, output_path):
    """Save dataset to JSONL format."""
    os.makedirs(os.path.dirname(output_path), exist_ok=True)
    with open(output_path, 'w', encoding='utf-8') as f:
        for item in dataset:
            f.write(json.dumps(item) + '\n')
    print(f"Saved JSONL to {output_path}")


@click.command()
@click.option('--dataset_name', default='user', help='Dataset name to download')
@click.option('--split', default='train', help='Dataset split (train, validation, test)')
def main(dataset_name, split):
    # Configurations
    jsonl_path = f"/tmp/{dataset_name}_{split}.jsonl"

    # Remote server details
    remote_user = os.environ.get("BSC_USER")
    remote_host = os.environ.get("BSC_HOST")
    remote_dir = os.environ.get("BSC_DIR", "")

    # Load dataset
    print(f"Loading dataset '{dataset_name}' split '{split}'...")
    dataset = load_dataset(dataset_name, split=split)
    print(f"Loaded dataset with {len(dataset)} rows")

    # Save as JSONL
    save_as_jsonl(dataset, jsonl_path)

    # Print the command for the user to copy-paste
    remote_part = f"{remote_user}@{remote_host}:{remote_dir}"
    if remote_dir and not remote_dir.endswith('/'):
        remote_part += '/'

    print("\n===========================================================")
    print(f"Dataset saved to: {jsonl_path}")
    print("To upload, copy and paste this command in your terminal:")
    print(f"\nscp {jsonl_path} {remote_part}\n")
    print("===========================================================\n")


if __name__ == "__main__":
    main()