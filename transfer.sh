#!/bin/bash

# ==========================
# S3 to Marenostrum transfer
# ==========================

BUCKET="s3:<bucket-name>/data_pii_removal/"
DEST="bsc:/gpfs/projects/<project_id>/myfolder/data/"
RCLONE_CMD="rclone copy"


# List of all folders

# List of all folders
AVAILABLE_FOLDERS=(
mdpi_1
mdpi_2
mdpi_3
mdpi_4
mdpi_5
mdpi_6
mdpi_7
mdpi_8
mdpi_9
mdpi_10
mdpi_11
mdpi_12
mdpi_13
mdpi_14
mdpi_15
mdpi_16
mdpi_17
mdpi_18
mdpi_19
mdpi_20
mdpi_21
mdpi_22
mdpi_23
mdpi_24
mdpi_25
mdpi_26
mdpi_27
)


# Show all available folders
echo "Available folders:"
for f in "${AVAILABLE_FOLDERS[@]}"; do
    echo " - $f"
done

# Ask user to input folder names
echo
read -p "Enter folder names to transfer (space-separated, or type ALL to transfer everything): " INPUT_FOLDERS

# Normalize input
INPUT_FOLDERS=$(echo "$INPUT_FOLDERS" | tr '[:upper:]' '[:lower:]')

# Build the final list of folders
FOLDERS=()
if [[ "$INPUT_FOLDERS" == "all" ]]; then
    FOLDERS=("${AVAILABLE_FOLDERS[@]}")
else
    for f in $INPUT_FOLDERS; do
        if [[ " ${AVAILABLE_FOLDERS[*]} " == *" $f "* ]]; then
            FOLDERS+=("$f")
        else
            echo "Warning: '$f' is not in the available folders list and will be skipped."
        fi
    done
fi

if [ ${#FOLDERS[@]} -eq 0 ]; then
    echo "No valid folders selected. Exiting."
    exit 1
fi

echo "You selected folders: ${FOLDERS[*]}"
read -p "Proceed with transfer? (Y/N): " CONFIRM
if [[ ! "$CONFIRM" =~ ^[Yy]$ ]]; then
    echo "Transfer cancelled."
    exit 0
fi

# Transfer selected folders
for FOLDER in "${FOLDERS[@]}"; do
    echo "Transferring $FOLDER ..."
    $RCLONE_CMD "${BUCKET}${FOLDER}" "${DEST}/${FOLDER}" --progress -vv
    echo "Done with $FOLDER"
    echo
done

echo "All selected folders transferred."
