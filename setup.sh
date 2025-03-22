#!/bin/bash

# Make script exit on error
set -e

echo "Setting up Logstash Syslog to Elasticsearch project..."

# Create directory structure if it doesn't exist
mkdir -p logstash/pipeline logstash/secrets logs

# Create a Python virtual environment if it doesn't exist
if [ ! -d "venv" ]; then
  echo "Creating Python virtual environment..."
  python -m venv venv || python3 -m venv venv
  
  # Activate the virtual environment
  source venv/bin/activate
  
  # Install dependencies
  echo "Installing Python dependencies..."
  pip install -r requirements.txt
  
  echo "Python virtual environment created and dependencies installed."
else
  echo "Python virtual environment already exists."
fi

# Ensure proper permissions for security
chmod 600 .env 2>/dev/null || echo "Warning: .env file not found. Make sure to create it before running docker-compose."
chmod 700 logstash/secrets

# Verify pipeline configuration exists
if [ ! -f logstash/pipeline/syslog-pipeline.conf ]; then
    echo "Error: syslog-pipeline.conf not found in logstash/pipeline directory."
    echo "Please ensure this file exists before continuing."
    exit 1
fi

# Create .env file from example if it doesn't exist
if [ ! -f .env ] && [ -f .env.example ]; then
    cp .env.example .env
    echo "Created .env file from .env.example. Please update it with your actual credentials."
fi

echo "Setup completed successfully!"
echo ""
echo "Next steps:"
echo "1. Ensure your .env file is configured with proper Elasticsearch credentials"
echo "2. Place your syslog files in the 'logs' directory or run download_logs.sh/.py to get sample logs"
echo "3. Activate the virtual environment with: source venv/bin/activate"
echo "4. Run 'python setup_datastream.py' to configure the Elasticsearch data stream"
echo "5. Start the system by running: docker-compose up -d"