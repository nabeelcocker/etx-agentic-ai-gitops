#!/bin/bash

# Script to run all admin scripts in order
# Usage: ./run-all.sh <number_of_users>

# Get the directory where this script is located
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Check if number of users is provided
if [ -z "$1" ]; then
    echo "Usage: $0 <number_of_users>"
    echo "Example: $0 7"
    exit 1
fi

NUM_USERS=$1

# Validate that NUM_USERS is a positive integer
if ! [[ "$NUM_USERS" =~ ^[1-9][0-9]*$ ]]; then
    echo "Error: Number of users must be a positive integer"
    exit 1
fi

echo "================================================================"
echo "Running all admin scripts for ${NUM_USERS} users"
echo "================================================================"
echo

# Array of scripts to run in order
SCRIPTS=(
    "01-create-mcp-github.sh"
    "02-update-llama-stack-config.sh"
    "03-create-ai-agent-pipelinerun.sh"
    "04-create-ai-agent-application.sh"
    "05-create-java-app-build.sh"
)

# Track if any script failed
FAILED=0

# Run each script in order
for script in "${SCRIPTS[@]}"; do
    SCRIPT_PATH="${SCRIPT_DIR}/${script}"
    
    if [ ! -f "${SCRIPT_PATH}" ]; then
        echo "Error: Script ${script} not found!"
        FAILED=1
        continue
    fi
    
    echo "================================================================"
    echo "Running: ${script}"
    echo "================================================================"
    echo
    
    # Make sure script is executable
    chmod +x "${SCRIPT_PATH}"
    
    # Run the script with the number of users parameter
    "${SCRIPT_PATH}" "${NUM_USERS}"
    
    # Check exit status
    if [ $? -ne 0 ]; then
        echo
        echo "✗ Script ${script} failed!"
        FAILED=1
        echo
        read -p "Continue with remaining scripts? (y/n): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            echo "Aborting execution."
            exit 1
        fi
    else
        echo
        echo "✓ Script ${script} completed successfully"
        echo
    fi
done

echo "================================================================"
if [ $FAILED -eq 0 ]; then
    echo "All scripts completed successfully!"
else
    echo "Some scripts failed. Please review the output above."
fi
echo "================================================================"

exit $FAILED

