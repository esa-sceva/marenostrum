#!/bin/bash

# === USAGE ===
# ./upload_to_marenostrum.sh <local_path> <bsc_username> <user>  [remote_path]
# Example:
# ./upload_to_marenostrum.sh ./hf_cache tijmen tijmen bsc21 /gpfs/projects/bsc21/myfolder/

# === INPUT ===
LOCAL_PATH="$1"
USERNAME="$2"
REMOTE_PATH="${3:-}"  # optional
GROUP=<project_id>

# === CHECKS ===
if [ -z "$LOCAL_PATH" ] || [ -z "$USERNAME" ] || [ -z "$USER" ]; then
    echo "Usage: $0 <local_path> <bsc_username>  [remote_path]"
    exit 1
fi

# === DEFAULT REMOTE DEST ===
if [ -z "$REMOTE_PATH" ]; then
    REMOTE_DEST="${USERNAME}@transfer1.bsc.es:"
else
    REMOTE_DEST="${USERNAME}@transfer1.bsc.es:${REMOTE_PATH}"
fi

# === COMMAND ===
CMD="rsync -avzP ${LOCAL_PATH} ${REMOTE_DEST}"

echo "Running command:"
echo "$CMD"
echo

# === EXECUTE ===
eval "$CMD"

if [ $? -eq 0 ]; then
    echo -e "\nUpload completed successfully."
else
    echo -e "\nUpload failed."
fi
