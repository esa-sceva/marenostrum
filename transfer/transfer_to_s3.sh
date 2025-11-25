#!/bin/bash
set -euo pipefail

# ==========================
# Marenostrum to S3 transfer
# ==========================

SRC="bsc:/gpfs/projects/<project_id>/myfolder/chunks/"
DEST="s3:<bucket-name>/chunks/"

echo "Starting transfer at $(date)"
echo "Source: $SRC"
echo "Destination: $DEST"

# Dry run option
read -p "Perform dry run first? (Y/N): " DRY_RUN
if [[ "$DRY_RUN" =~ ^[Yy]$ ]]; then
    RCLONE_CMD="rclone copy --dry-run"
    echo "=== DRY RUN MODE ==="
else
    RCLONE_CMD="rclone copy"
fi

read -p "Proceed with transfer? (Y/N): " CONFIRM
if [[ ! "$CONFIRM" =~ ^[Yy]$ ]]; then
    echo "Transfer cancelled."
    exit 0
fi

# Transfer entire directory structure in one go
echo "=== Starting transfer of all subfolders at $(date) ==="

$RCLONE_CMD \
    "$SRC" "$DEST" \
    --progress -vv \
    --transfers=64 \
    --checkers=128 \
    --buffer-size=64M \
    --fast-list \
    --s3-chunk-size=16M \
    --s3-upload-concurrency=16 \
    --low-level-retries=20 \
    --retries=10 \
    --checksum \
    --timeout=6h \
    --contimeout=15m \
    --bwlimit=50M \
    --create-empty-src-dirs

EXIT_CODE=$?
if [ $EXIT_CODE -eq 0 ]; then
    echo "=== All subfolders transferred successfully at $(date) ==="
else
    echo "=== ERROR: Transfer failed with exit code $EXIT_CODE at $(date) ==="
    exit $EXIT_CODE
fi

echo "Transfer completed at $(date)"