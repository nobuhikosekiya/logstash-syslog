#!/bin/bash

# Make script exit on error
set -e

# Create logs directory if it doesn't exist
mkdir -p logs

echo "Starting download of log files from Zenodo..."

# Download Windows logs
echo "Downloading Windows logs..."
curl -L "https://zenodo.org/records/8196385/files/Windows.tar.gz?download=1" -o logs/Windows.tar.gz
echo "Windows logs downloaded successfully."

# Download Linux logs
echo "Downloading Linux logs..."
curl -L "https://zenodo.org/records/8196385/files/Linux.tar.gz?download=1" -o logs/Linux.tar.gz
echo "Linux logs downloaded successfully."

# Download Mac logs
echo "Downloading Mac logs..."
curl -L "https://zenodo.org/records/8196385/files/Mac.tar.gz?download=1" -o logs/Mac.tar.gz
echo "Mac logs downloaded successfully."

echo "All downloads completed."

# Extract the files
echo "Extracting log files..."
cd logs
tar -xzf Windows.tar.gz
tar -xzf Linux.tar.gz
tar -xzf Mac.tar.gz

# Optional: Remove the tar.gz files to save space