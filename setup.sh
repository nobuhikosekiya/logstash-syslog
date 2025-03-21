#!/bin/bash

# Create directory structure
mkdir -p logstash/pipeline logstash/secrets logs

# Ensure configuration file exists in the root directory
cp syslog-pipeline.conf logstash/pipeline/

# Set permissions
chmod 600 .env
chmod 700 logstash/secrets

echo "Directory structure created. Please place your syslog files in the 'logs' directory."
echo "Make sure to update the .env file with your actual Elasticsearch Cloud ID and API Key."
echo "Start the system by running: docker-compose up -d"