# Transfer Utilities

This folder contains utility scripts for transferring data between S3, MareNostrum, and managing storage on the HPC cluster, given that the Marenostrum HPC has no internet access.

## Scripts Overview

### 1. `transfer.sh` - Download from S3 to MareNostrum

**Purpose**: Interactive script to download datasets from S3 to MareNostrum.

**Features**:
- Interactive folder selection
- Download individual folders or all at once
- Input validation
- Confirmation prompts

**Usage**:

```bash
# On MareNostrum
cd /gpfs/projects/<project_id>/satcom
./transfer/transfer.sh

# The script will:
# 1. Show available folders
# 2. Ask which folders to download
# 3. Confirm before starting transfer
```

**Configuration**:
- **Source**: `s3:<bucket-name>/data_pii_removal/`
- **Destination**: `bsc:/gpfs/projects/<project_id>/myfolder/data/`

**Example Session**:

```
Available folders:
 - wikipedia

Enter folder names to transfer (space-separated, or type ALL to transfer everything): wikipedia
You selected folders: wikipedia
Proceed with transfer? (Y/N): Y
Transferring wikipedia ...
```

**Customization**:

Edit the script to modify the list of available folders:

```bash
AVAILABLE_FOLDERS=(
    wikipedia
    arxiv
    mdpi
)
```

---

### 2. `transfer_to_s3.sh` - Upload from MareNostrum to S3

**Purpose**: Optimized script to upload results from MareNostrum to S3.

**Features**:
- Dry-run mode for testing
- Optimized for large transfers with parallel operations
- Checksums for data integrity
- Automatic retries
- Bandwidth limiting to avoid network congestion

**Usage**:

```bash
# On MareNostrum
cd /gpfs/projects/<project_id>/satcom
./transfer/transfer_to_s3.sh

# The script will:
# 1. Ask if you want a dry-run first
# 2. Show transfer details
# 3. Confirm before starting upload
```

**Configuration**:
- **Source**: `bsc:/gpfs/projects/<project_id>/myfolder/chunks/`
- **Destination**: `s3:<bucket-name>/chunks/`

**Optimization Parameters**:
```bash
--transfers=64              # 64 parallel file transfers
--checkers=128              # 128 parallel checksum checks
--buffer-size=64M           # 64MB buffer per transfer
--s3-chunk-size=16M         # 16MB chunks for S3 multipart
--s3-upload-concurrency=16  # 16 concurrent S3 uploads
--bwlimit=50M               # Limit to 50MB/s
--checksum                  # Verify with checksums
```

**Example Session**:

```
Starting transfer at Mon Jan 15 14:30:00 2025
Source: bsc:/gpfs/projects/<project_id>/myfolder/chunks/
Destination: s3:<bucket-name>/chunks/
Perform dry run first? (Y/N): N
Proceed with transfer? (Y/N): Y
=== Starting transfer of all subfolders ===
```

**Customization**:

Edit source and destination paths:

```bash
SRC="bsc:/gpfs/projects/<project_id>/myfolder/results/"
DEST="s3:<bucket-name>/synthetic-data-gen/results/"
```

---

### 3. `simple_move.sh` - Move Between Project and Scratch Storage

**Purpose**: Move data between folders on MareNostrum.

**Features**:
- Simple one-command data migration
- Automatically creates destination directory
- Useful for managing storage quotas

**Usage**:

```bash
# On MareNostrum
cd /gpfs/projects/<project_id>/satcom
./transfer/simple_move.sh
```

**Configuration**:
- **Source**: `/gpfs/projects/<project_id>/myfolder/`
- **Destination**: `/gpfs/scratch/<project_id>/myfolder/`

**Use Cases**:

1. **Free up project space**: Move large intermediate files to scratch
2. **Temporary storage**: Use scratch for processing, move final results back to project
3. **Archive management**: Move old datasets to scratch before deletion

**Important Notes**:
- Use project storage for long-term data
- Use scratch storage for temporary/intermediate files



---


## Common Workflows

### Downloading and Processing Dataset

```bash
# 1. Download dataset to scratch
cd /gpfs/projects/<project_id>/satcom
# Edit transfer.sh: DEST="bsc:/gpfs/scratch/<project_id>/myfolder/data/"
./transfer/transfer.sh

# 2. Run processing job (outputs to scratch)
# Edit job config: INPUT_SOURCE="/gpfs/scratch/<project_id>/myfolder/data/..."
#                  OUTPUT_DESTINATION="/gpfs/scratch/<project_id>/myfolder/results/"

# 3. Move final results to project
mkdir -p /gpfs/projects/<project_id>/myfolder/final_results
mv /gpfs/scratch/<project_id>/myfolder/results/final_output.jsonl /gpfs/projects/<project_id>/myfolder/final_results/

# 4. Upload to S3
# Edit transfer_to_s3.sh: SRC="bsc:/gpfs/projects/<project_id>/myfolder/final_results/"
./transfer/transfer_to_s3.sh
```

### Managing Storage Quotas

```bash
# Check storage usage
du -sh /gpfs/projects/<project_id>/myfolder/*
du -sh /gpfs/scratch/<project_id>/myfolder/*

# Move old logs to scratch
mv /gpfs/projects/<project_id>/myfolder/slurm_out /gpfs/scratch/<project_id>/myfolder/old_logs

# Clean up scratch after upload
rm -rf /gpfs/scratch/<project_id>/myfolder/temp_data
```

---

## Troubleshooting

### Transfer Fails

**Symptom**: rclone errors during transfer

**Solutions**:
1. Check rclone config: `rclone config`
2. Test connection: `rclone lsd s3:<bucket-name>`
3. Check network: `ping transfer1.bsc.es`
4. Use dry-run mode to test

### Out of Quota

**Symptom**: "Disk quota exceeded"

**Solutions**:
1. Check usage: `quota -s`
2. Move to scratch: `./transfer/simple_move.sh`
3. Clean up old files: `rm -rf old_data/`
4. Upload to S3 and delete local: `./transfer/transfer_to_s3.sh`

### Slow Transfers

**Symptom**: Transfer takes very long

**Solutions**:
1. Increase parallelism in `transfer_to_s3.sh`:
   ```bash
   --transfers=128
   --checkers=256
   ```
2. Check bandwidth limit: Remove or increase `--bwlimit`
3. Use transfer nodes (not login nodes)
4. Run transfer as background job

---

## Additional Resources

- [Main README](../README.md) - Overview and setup
- [COMMANDS.md](../COMMANDS.md) - Quick command reference
- [rclone Documentation](https://rclone.org/docs/)
- [MareNostrum Storage Guide](https://www.bsc.es/user-support/mn4.php#storage)

