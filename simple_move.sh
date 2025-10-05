#!/bin/bash

# Simple script to move data from gpfs_projects to gpfs_scratch

SOURCE="/gpfs/projects/<project_id>/satcom"
DEST="/gpfs/scratch/<project_id>/satcom"

echo "Moving data from $SOURCE to $DEST"

# Create destination directory
mkdir -p "$DEST"

# Move the data
mv "$SOURCE"/* "$DEST/"

echo "Move completed!"
echo "Data is now at: $DEST"


