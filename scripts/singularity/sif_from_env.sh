#!/bin/bash

# Script to build Singularity container with dynamic environment variable injection

# Check if required arguments are provided
if [ $# -ne 3 ]; then
    echo "Usage: $0 <env_file> <template_file> <output_file>"
    echo "Example: $0 .env singularity.def.template singularity.def"
    exit 1
fi

# Get file names from command line arguments
ENV_FILE="$1"
TEMPLATE_FILE="$2"
OUTPUT_FILE="$3"

# Check if .env file exists
if [ ! -f "$ENV_FILE" ]; then
    echo "Error: $ENV_FILE file not found!"
    echo "Please create a $ENV_FILE file with the required environment variables."
    exit 1
fi

# Check if template file exists
if [ ! -f "$TEMPLATE_FILE" ]; then
    echo "Error: $TEMPLATE_FILE file not found!"
    echo "Please create the template file."
    exit 1
fi

echo "Processing environment variables from $ENV_FILE..."

# Create temporary files
ENV_TEMP=$(mktemp)
ENV_LOOKUP=$(mktemp)
PROCESSED_TEMP=$(mktemp)

# Function to get variable value from lookup file
get_var_value() {
    local var_name="$1"
    grep "^$var_name=" "$ENV_LOOKUP" | cut -d'=' -f2- | head -1
}

# Function to substitute variables in a line
substitute_variables() {
    local line="$1"
    local result="$line"

    # Use sed to find and replace $VARIABLE patterns
    while echo "$result" | grep -q '\$[A-Za-z_][A-Za-z0-9_]*'; do
        # Extract the variable name
        local var_name=$(echo "$result" | sed 's/.*\$\([A-Za-z_][A-Za-z0-9_]*\).*/\1/')
        local var_value=$(get_var_value "$var_name")

        # Check if variable exists
        if [ -n "$var_value" ]; then
            # Replace the variable with its value
            result=$(echo "$result" | sed "s/\\\$$var_name/$var_value/g")
        else
            echo "Error: Variable \$$var_name found in template but not defined in $ENV_FILE"
            rm -f "$ENV_TEMP" "$ENV_LOOKUP" "$PROCESSED_TEMP"
            exit 1
        fi
    done

    echo "$result"
}

# Process .env file and create lookup table
while IFS='=' read -r key value || [ -n "$key" ]; do
    # Skip empty lines and comments
    case "$key" in
        ''|'#'*) continue ;;
    esac

    # Remove leading/trailing whitespace
    key=$(echo "$key" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
    value=$(echo "$value" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')

    # Store key-value pair in lookup file
    echo "$key=$value" >> "$ENV_LOOKUP"

    # Add export statement to temp file
    echo "    export $key=$value" >> "$ENV_TEMP"

    # Also export for the build process
    export "$key=$value"

done < "$ENV_FILE"

# Process the template file
in_post_section=false
while IFS= read -r line; do
    # Check for environment variables injection point
    if echo "$line" | grep -q "# Environment variables will be injected here from .env file"; then
        cat "$ENV_TEMP"
        continue
    fi

    # Check if we're entering %post section
    if echo "$line" | grep -q "^%post"; then
        in_post_section=true
        echo "$line"
        continue
    fi

    # Check if we're entering another section
    if echo "$line" | grep -q "^%"; then
        in_post_section=false
        echo "$line"
        continue
    fi

    # If we're in %post section, substitute variables
    if [ "$in_post_section" = true ]; then
        substitute_variables "$line"
    else
        echo "$line"
    fi
done < "$TEMPLATE_FILE" > "$OUTPUT_FILE"

# Clean up temp files
rm -f "$ENV_TEMP" "$ENV_LOOKUP" "$PROCESSED_TEMP"

echo "Generated $OUTPUT_FILE with the following environment variables:"
echo "Environment variables injected:"
grep "export" "$OUTPUT_FILE" | sed 's/^/  /'

echo ""
echo "Variables substituted in %post section:"
# Show which variables were found and substituted
while IFS='=' read -r key value; do
    case "$key" in
        ''|'#'*) continue ;;
    esac
    key=$(echo "$key" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
    value=$(echo "$value" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
    if grep -q "\$$key" "$TEMPLATE_FILE"; then
        echo "  \$$key -> $value"
    fi
done < "$ENV_FILE"

# Build the container
echo ""
echo "Building Singularity container..."
singularity build --fakeroot container.sif "$OUTPUT_FILE"

echo "Build completed!"
echo "Generated files:"
echo "  - $OUTPUT_FILE (final Singularity definition)"
echo "  - container.sif (built container)"