#!/bin/bash

# --- GCI DATA COLLECTOR START SCRIPT (macOS/Linux) ---

# Get the directory where this script is located
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
cd "$SCRIPT_DIR"

echo "--- GCI DATA COLLECTOR STARTING ---"

# Check for python3, fallback to python
if command -v python3 &>/dev/null; then
    PYTHON_CMD="python3"
elif command -v python &>/dev/null; then
    PYTHON_CMD="python"
else
    echo "❌ Error: Python is not installed. Please install Python to run the scraper."
    exit 1
fi

echo "Using: $PYTHON_CMD"
echo "Script: python/main.py"

# Run the python script
$PYTHON_CMD python/main.py
