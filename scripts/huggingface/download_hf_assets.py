import os
import yaml
import tempfile
import shutil
from huggingface_hub import snapshot_download
from datasets import load_dataset
import click


@click.command()
@click.argument("config_file", type=str)
def main(config_file: str):
    # === Load YAML config ===
    with open(config_file, "r") as f:
        config = yaml.safe_load(f)

    models = config.get("models", [])
    datasets = config.get("datasets", [])
    hf_cache_dir = config.get("hf_cache_dir", os.path.join(os.path.expanduser("~"), ".cache", "huggingface"))
    print(f"Cache directory: {hf_cache_dir}")

    # === Create all necessary directories ===
    os.makedirs(hf_cache_dir, exist_ok=True)
    datasets_cache = os.path.join(hf_cache_dir, "datasets")
    models_cache = os.path.join(hf_cache_dir, "models")
    metrics_cache = os.path.join(hf_cache_dir, "metrics")
    temp_dir = os.path.join(hf_cache_dir, "temp")

    os.makedirs(datasets_cache, exist_ok=True)
    os.makedirs(models_cache, exist_ok=True)
    os.makedirs(metrics_cache, exist_ok=True)
    os.makedirs(temp_dir, exist_ok=True)

    # === Set ALL relevant environment variables ===
    os.environ["HF_HOME"] = hf_cache_dir
    os.environ["HF_DATASETS_CACHE"] = datasets_cache
    os.environ["TRANSFORMERS_CACHE"] = models_cache
    os.environ["HF_METRICS_CACHE"] = metrics_cache

    # Force temporary directory to use our custom location
    os.environ["TMPDIR"] = temp_dir
    os.environ["TMP"] = temp_dir
    os.environ["TEMP"] = temp_dir

    # Additional HF-specific environment variables
    os.environ["HF_DATASETS_DOWNLOADED_DATASETS_PATH"] = datasets_cache
    os.environ["HF_DATASETS_EXTRACTED_DATASETS_PATH"] = datasets_cache
    os.environ["HF_HUB_CACHE"] = os.path.join(hf_cache_dir, "hub")

    # Set Python's tempfile to use our directory
    tempfile.tempdir = temp_dir

    print(f"Temporary directory set to: {temp_dir}")
    print(f"Available space in cache dir: {shutil.disk_usage(hf_cache_dir).free // (1024 ** 3)} GB")

    # === Download models ===
    print("\n🔄 Downloading models...")
    for model_id in models:
        print(f" -> {model_id}")
        try:
            snapshot_download(
                repo_id=model_id,
                cache_dir=models_cache,
                local_dir_use_symlinks=False,  # Avoid symlinks which can cause issues
                resume_download=True,  # Resume interrupted downloads
            )
            print(f"   ✅ Successfully downloaded {model_id}")
        except Exception as e:
            print(f"   ⚠️ Failed to download {model_id}: {e}")
            continue

    # === Download datasets ===
    print("\n🔄 Downloading datasets...")
    for ds in datasets:
        name = ds["name"]
        subset = ds.get("subset")
        print(f" -> {name}" + (f" ({subset})" if subset else ""))
        try:
            load_dataset(
                path=name,
                name=subset,
                cache_dir=datasets_cache,
                download_mode="reuse_dataset_if_exists",  # Reuse if already downloaded
            )
            print(f"   ✅ Successfully downloaded {name}")
        except Exception as e:
            print(f"   ⚠️ Failed to download {name}: {e}")
            continue

    # === Cleanup temporary files ===
    print("\n🧹 Cleaning up temporary files...")
    try:
        # Clean up the temporary directory
        if os.path.exists(temp_dir):
            for item in os.listdir(temp_dir):
                item_path = os.path.join(temp_dir, item)
                if os.path.isdir(item_path):
                    shutil.rmtree(item_path)
                else:
                    os.remove(item_path)
    except Exception as e:
        print(f"   ⚠️ Warning: Could not clean all temporary files: {e}")

    print(f"\n✅ Done! Cache is in: {hf_cache_dir}")
    print(f"Final cache size: {get_dir_size(hf_cache_dir) / (1024 ** 3):.2f} GB")


def get_dir_size(path):
    """Calculate total size of directory"""
    total = 0
    try:
        for dirpath, dirnames, filenames in os.walk(path):
            for filename in filenames:
                filepath = os.path.join(dirpath, filename)
                if os.path.exists(filepath):
                    total += os.path.getsize(filepath)
    except Exception as e:
        print(f"Warning: Could not calculate size for {path}: {e}")
    return total


if __name__ == "__main__":
    main()