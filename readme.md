# Logstash Syslog to Elasticsearch

This setup allows you to process syslog files from a mounted directory and ingest them into Elasticsearch using Logstash 8.

## Configuration Overview

- **Logstash**: Reads syslog files, parses them, and sends them to Elasticsearch using data streams
- **Data Stream**: Optimized for time-series data like logs
- **Python Script**: Sets up the required data stream in Elasticsearch
- **Character Encoding Handling**: Safely processes logs containing binary data or non-UTF-8 characters

## Prerequisites

- Docker and Docker Compose installed
- Elasticsearch deployment (cloud or self-hosted)
- Syslog-formatted log files

## Setup Instructions

1. **Clone or download this repository**

2. **Install Python requirements**
   ```bash
   pip install -r requirements.txt
   ```

3. **Update the environment variables**

   Edit the `.env` file and update the following variables:
   ```
   ES_ENDPOINT="https://your-es-endpoint.cloud.es.io"
   ES_PORT=443  # Default: 443 for HTTPS, 9200 for HTTP
   ELASTIC_LOGSTASH_API_KEY=your_logstash_api_key_here
   ELASTIC_ADMIN_API_KEY=your_admin_api_key_here
   ```
   
   **Note**: You need two different API keys:
   - `ELASTIC_LOGSTASH_API_KEY` needs write permissions to the data stream
   - `ELASTIC_ADMIN_API_KEY` needs index management permissions to create data streams

4. **Run the setup script**
   ```bash
   chmod +x setup.sh
   ./setup.sh
   ```

5. **Set up the Elasticsearch data stream**
   ```bash
   # Activate the virtual environment
   source venv/bin/activate
   
   # The script will automatically read from .env file
   python setup_datastream.py
   
   # Optionally, you can override the values:
   python setup_datastream.py --es-endpoint "https://your-es-endpoint.cloud.es.io" --api-key "your_api_key_here"
   ```

6. **Place your syslog files in the `logs` directory**
   ```bash
   cp /path/to/your/syslog/files/*.log logs/
   ```

7. **Start the containers**
   ```bash
   docker-compose up -d
   ```

8. **Run the test script (optional)**
   ```bash
   chmod +x test_setup.sh
   ./test_setup.sh
   ```

## Indexed Fields

The following fields will be indexed in Elasticsearch:

### Core Fields (from your logs)
- `@timestamp`: The timestamp extracted from the syslog entry
- `host.name`: The server name extracted from the syslog entry
- `message`: The log message content

### Automatically Added Fields
- `@version`: Added by Logstash to every event (typically "1")
- `log.file.path`: The source log file path
- `event.original`: The original unparsed log message (may be present)
- `data_stream.*`: Metadata for the Elasticsearch data stream:
  - `data_stream.type`: Set to "logs"
  - `data_stream.dataset`: Set to "syslog" 
  - `data_stream.namespace`: Set to "default"

### Elasticsearch Fields
- `.keyword` subfields: Automatically created for text fields
- `_data_stream_timestamp`: Created for data stream management

## Directory Structure

```
.
├── docker-compose.yml
├── .env
├── logstash.yml                  # Logstash main configuration template
├── logs/                         # Place your syslog files here
├── logstash/
│   ├── pipeline/
│   │   └── syslog-pipeline.conf  # Logstash pipeline configuration
│   └── secrets/                  # For any sensitive files
├── requirements.txt              # Python dependencies
├── setup_datastream.py           # Python script to create Elasticsearch data stream
├── setup.sh                      # Setup script
├── test_setup.sh                 # Test script for verification
├── download_logs.sh              # Bash script to download sample logs
└── download_logs.py              # Python script to download sample logs
```

## Monitoring

You can check Logstash's status at `http://localhost:9600`.

## Customization

- To modify the parsing pattern, edit the `grok` filter in `syslog-pipeline.conf`.
- To adjust system resources, modify the `LS_JAVA_OPTS` in `docker-compose.yml`.
- To remove specific fields from indexing, add a `mutate { remove_field => [...] }` filter.
- For debugging, uncomment the `stdout` output in `syslog-pipeline.conf`.

## Troubleshooting

**Issue**: Logstash is not picking up new files.
**Solution**: Verify file permissions and restart Logstash.
```bash
docker-compose restart logstash
```

**Issue**: Connection to Elasticsearch fails.
**Solution**: Verify your ES_ENDPOINT, ES_PORT, and API keys in the `.env` file.

**Issue**: Character encoding warnings in logs.
**Solution**: The pipeline includes a Ruby filter to handle encoding issues by converting non-UTF-8 characters to question marks. This preserves potentially important security information while ensuring compatibility with Elasticsearch.