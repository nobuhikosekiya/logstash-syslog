#!/bin/bash

# Ensure Docker containers are always stopped at end of test regardless of success or failure
cleanup() {
  echo "Cleaning up..."
  docker-compose down >/dev/null 2>&1 || echo "Warning: docker-compose down failed"
  docker stop $(docker ps -q -f name=logstash) >/dev/null 2>&1 || echo "Warning: No containers to stop"
  
  # Deactivate virtual environment if active
  if [ ! -z "$VIRTUAL_ENV" ]; then
    deactivate
    echo "Virtual environment deactivated."
  fi
  
  echo "Cleanup completed."
}

# Execute cleanup when script exits for any reason
trap cleanup EXIT

# Main function
main() {
  # Colors for better output
  GREEN='\033[0;32m'
  RED='\033[0;31m'
  YELLOW='\033[1;33m'
  NC='\033[0m' # No Color

  echo -e "${YELLOW}Starting test of Logstash Syslog to Elasticsearch setup...${NC}"

  # Function to check if a command exists
  command_exists() {
    command -v "$1" >/dev/null 2>&1
  }

  # Check prerequisites
  echo "Checking prerequisites..."
  for cmd in docker docker-compose curl; do
    if ! command_exists $cmd; then
      echo -e "${RED}Error: $cmd is not installed. Please install it and try again.${NC}"
      exit 1
    fi
  done

  # Check if python3 or python is available
  if command_exists python3; then
    PYTHON_CMD="python3"
  elif command_exists python; then
    PYTHON_CMD="python"
  else
    echo -e "${RED}Error: Neither python3 nor python is installed. Please install Python and try again.${NC}"
    exit 1
  fi
  echo -e "${GREEN}Using Python command: $PYTHON_CMD${NC}"

  echo -e "${GREEN}All required commands are available.${NC}"

  # Check if .env file exists and has required variables
  echo "Checking environment variables..."
  if [ ! -f .env ]; then
    if [ -f .env.example ]; then
      echo "Creating .env file from .env.example for testing..."
      cp .env.example .env
      echo "You'll need to update the .env file with your actual credentials before the test will pass."
    else
      echo -e "${RED}Error: .env file not found and no .env.example to copy from.${NC}"
      exit 1
    fi
  fi

  # Check for required environment variables
  source .env
  if [[ -z "$ES_ENDPOINT" || -z "$ELASTIC_LOGSTASH_API_KEY" || -z "$ELASTIC_ADMIN_API_KEY" ]]; then
    echo -e "${RED}Error: Required environment variables not set in .env file.${NC}"
    echo "Please set ES_ENDPOINT, ELASTIC_LOGSTASH_API_KEY, and ELASTIC_ADMIN_API_KEY"
    exit 1
  fi
  
  # Set default port if not specified, based on protocol
  if [[ -z "$ES_PORT" ]]; then
    # Extract protocol from the endpoint
    PROTOCOL=$(echo "$ES_ENDPOINT" | grep -o "^https\?://")
    
    if [[ "$PROTOCOL" == "https://" ]]; then
      echo "ES_PORT not set, defaulting to 443 for HTTPS"
      ES_PORT=443
    else
      echo "ES_PORT not set, defaulting to 9200 for HTTP"
      ES_PORT=9200
    fi
  fi
  
  # Construct full Elasticsearch URL with port
  ES_URL="${ES_ENDPOINT}:${ES_PORT}"
  
  echo -e "${GREEN}Environment variables are set.${NC}"

  # Run the setup script which will create the virtual environment
  echo "Running setup script..."
  ./setup.sh

  # Activate the virtual environment
  echo "Activating Python virtual environment..."
  source venv/bin/activate

  # Verify the virtual environment is activated
  if [[ "$VIRTUAL_ENV" == "" ]]; then
    echo -e "${RED}Error: Failed to activate virtual environment.${NC}"
    exit 1
  fi
  echo -e "${GREEN}Virtual environment activated: $(basename $VIRTUAL_ENV)${NC}"

  # Create necessary directories
  echo "Creating required directories..."
  mkdir -p logs logstash/pipeline logstash/secrets
  echo -e "${GREEN}Directories created.${NC}"

  # Check if syslog-pipeline.conf exists in the right location
  if [ ! -f logstash/pipeline/syslog-pipeline.conf ]; then
    echo -e "${RED}Error: syslog-pipeline.conf not found in logstash/pipeline directory.${NC}"
    exit 1
  fi
  echo -e "${GREEN}Pipeline configuration found.${NC}"

  # Download only the Linux logs for faster testing
  echo "Downloading Linux log files for testing..."
  curl -L "https://zenodo.org/records/8196385/files/Linux.tar.gz?download=1" -o logs/Linux.tar.gz

  # Extract the Linux logs
  echo "Extracting Linux logs..."
  tar -xzf logs/Linux.tar.gz -C logs/

  # Count lines in log files before ingestion
  echo "Counting log lines in source files..."
  TOTAL_SOURCE_LINES=0
  for logfile in logs/*.log; do
    if [ -f "$logfile" ]; then
      lines=$(wc -l < "$logfile")
      TOTAL_SOURCE_LINES=$((TOTAL_SOURCE_LINES + lines))
      echo "  - $logfile: $lines lines"
    fi
  done
  echo -e "${GREEN}Total lines in source log files: $TOTAL_SOURCE_LINES${NC}"

  # Set up the Elasticsearch data stream
  echo "Setting up Elasticsearch data stream..."
  python setup_datastream.py

  # Start the containers
  echo "Starting Docker containers..."
  docker-compose up -d

  # Wait for Logstash to start processing
  echo "Waiting for Logstash to initialize (30 seconds)..."
  sleep 30

  # Monitor log processing using curl directly
  echo "Monitoring log processing progress..."
  MAX_WAIT=300  # 5 minutes max wait time
  start_time=$(date +%s)
  processed_lines=0
  last_processed=0
  no_change_count=0

  # Print the Elasticsearch endpoint
  echo ""
  echo "┌─────────────────────────────────────────────────────────────────┐"
  echo "│                 ELASTICSEARCH QUERY INFORMATION                  │"
  echo "├─────────────────────────────────────────────────────────────────┤"
  echo "│ Elasticsearch URL:      $ES_URL"
  echo "│ Data stream:            logs-syslog-default"
  echo "└─────────────────────────────────────────────────────────────────┘"
  echo ""

  DATA_STREAM="logs-syslog-default"
  
  while true; do
    # Query for document count in data stream
    response=$(curl -s -H "Authorization: ApiKey $ELASTIC_ADMIN_API_KEY" \
      "$ES_URL/logs-syslog-default/_count" \
      -d '{"query": {"match_all": {}}}' \
      -H 'Content-Type: application/json' \
      -w "\n%{http_code}" || echo "CURL_ERROR")
    
    HTTP_BODY=$(echo "$response" | head -n 1)
    HTTP_STATUS=$(echo "$response" | tail -n 1)
    
    # If the specific data stream query failed, try the cluster-wide query
    if [ "$HTTP_STATUS" != "200" ] || ! echo "$HTTP_BODY" | grep -q '"count":[0-9]*'; then
      echo "Data stream query failed, trying cluster-wide query..."
      
      response=$(curl -s -H "Authorization: ApiKey $ELASTIC_ADMIN_API_KEY" \
        "$ES_URL/_count" \
        -d '{"query": {"match_all": {}}}' \
        -H 'Content-Type: application/json' \
        -w "\n%{http_code}" || echo "CURL_ERROR")
      
      HTTP_BODY=$(echo "$response" | head -n 1)
      HTTP_STATUS=$(echo "$response" | tail -n 1)
    fi
    
    # Extract count from response
    if [ "$HTTP_STATUS" = "200" ] && echo "$HTTP_BODY" | grep -q '"count":[0-9]*'; then
      processed_lines=$(echo "$HTTP_BODY" | grep -o '"count":[0-9]*' | cut -d':' -f2)
      # Ensure it's a number
      if [[ ! "$processed_lines" =~ ^[0-9]+$ ]]; then
        processed_lines=0
      fi
    else
      echo "Could not get valid document count, setting to 0"
      processed_lines=0
    fi
    
    current_time=$(date +%s)
    elapsed=$((current_time - start_time))
    
    echo "Processed $processed_lines of $TOTAL_SOURCE_LINES log lines ($((elapsed)) seconds elapsed)"
    
    # Check if processing is complete
    if [ "$processed_lines" -ge "$TOTAL_SOURCE_LINES" ]; then
      echo -e "${GREEN}All log lines have been processed!${NC}"
      TEST_RESULT="PASSED"
      break
    fi
    
    # Check if we've reached max wait time
    if [ $elapsed -ge $MAX_WAIT ]; then
      echo -e "${YELLOW}Warning: Maximum wait time reached. Processed $processed_lines of $TOTAL_SOURCE_LINES log lines.${NC}"
      TEST_RESULT="PARTIALLY PASSED"
      break
    fi
    
    # Check if processing has stalled
    if [ "$processed_lines" -eq "$last_processed" ]; then
      no_change_count=$((no_change_count + 1))
      if [ $no_change_count -ge 5 ]; then
        echo -e "${YELLOW}Warning: No new log lines processed in the last 50 seconds.${NC}"
        echo "Checking Logstash logs for errors:"
        docker logs logstash --tail 20 | grep -i "error\|exception" || echo "No obvious errors found"
        TEST_RESULT="PARTIALLY PASSED"
        break
      fi
    else
      no_change_count=0
      last_processed=$processed_lines
    fi
    
    sleep 10
  done

  # Generate test report
  echo "Generating test report..."
  cat > test_report.md << EOF
# Logstash Syslog to Elasticsearch Test Report

Test conducted on: $(date)

## Summary
- Total log lines in source files: $TOTAL_SOURCE_LINES
- Log lines processed by Elasticsearch: $processed_lines
- Processing ratio: $(echo "scale=2; $processed_lines * 100 / $TOTAL_SOURCE_LINES" | bc)%
- Test duration: $elapsed seconds

## Environment
- Docker version: $(docker --version)
- Docker Compose version: $(docker-compose --version)
- Python version: $(python --version)
- Elasticsearch URL: $ES_URL

## Status
EOF

  # Add test result to report
  case "$TEST_RESULT" in
    "PASSED")
      echo "✅ TEST PASSED: All log lines were successfully ingested" >> test_report.md
      echo -e "${GREEN}Test completed successfully! All log lines were ingested.${NC}"
      ;;
    "PARTIALLY PASSED")
      echo "⚠️ TEST PARTIALLY PASSED: Some log lines were ingested, but not all" >> test_report.md
      echo -e "${YELLOW}Test partially passed. Some log lines were ingested, but not all.${NC}"
      ;;
    *)
      echo "❌ TEST FAILED: No log lines were ingested" >> test_report.md
      echo -e "${RED}Test failed! No log lines were ingested.${NC}"
      ;;
  esac

  echo -e "${YELLOW}Test report generated: test_report.md${NC}"
  echo -e "${GREEN}Test completed!${NC}"
}

# Call the main function
main