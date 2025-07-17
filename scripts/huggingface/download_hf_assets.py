import os
import yaml
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
    print(hf_cache_dir)

    # === Set HF cache env variables ===
    os.makedirs(hf_cache_dir, exist_ok=True)
    os.environ["HF_HOME"] = hf_cache_dir
    os.environ["HF_DATASETS_CACHE"] = os.path.join(hf_cache_dir, "datasets")
    os.environ["TRANSFORMERS_CACHE"] = os.path.join(hf_cache_dir, "models")
    os.environ["HF_METRICS_CACHE"] = os.path.join(hf_cache_dir, "metrics")
    os.environ["HF_XET_CACHE"] = os.path.join(hf_cache_dir, "xet")

    # === Download models ===
    print("🔄 Downloading models...")
    for model_id in models:
        print(f" -> {model_id}")
        snapshot_download(
            repo_id=model_id,
            cache_dir=os.environ["TRANSFORMERS_CACHE"],
        )

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
                cache_dir=os.environ["HF_DATASETS_CACHE"]
            )
        except Exception as e:
            print(f"   ⚠️ Failed: {e}")

    print("\n✅ Done! Cache is in:", hf_cache_dir)

if __name__ == "__main__":
    main()