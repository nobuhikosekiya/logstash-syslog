# Logstash Syslog to Elasticsearch

This setup allows you to process syslog files from a mounted directory and ingest them into Elasticsearch using Logstash 8.

## Configuration Overview

- **Logstash**: Reads syslog files, parses them, and sends them to Elasticsearch using data streams
- **Data Stream**: Optimized for time-series data like logs
- **Python Script**: Sets up the required data stream in Elasticsearch
- **Field Mapping**:
  - `@timestamp`: The timestamp from the syslog entry
  - `host.name`: The server name from the syslog entry
  - `message`: The original log message
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
   ELASTIC_CLOUD_ID=your_cloud_id_here
   ELASTIC_LOGSTASH_API_KEY=your_logstash_api_key_here
   ELASTIC_ADMIN_API_KEY=your_admin_api_key_here
   ```
   
   **Note**: You need two different API keys:
   - `ELASTIC_LOGSTASH_API_KEY` needs write permissions to the data stream
   - `ELASTIC_ADMIN_API_KEY` needs index management permissions to create data streams

4. **Make the setup script executable**
   ```bash
   chmod +x setup.sh
   ```

5. **Run the setup script**
   ```bash
   ./setup.sh
   ```

6. **Set up the Elasticsearch data stream**
   ```bash
   # The script will automatically read from .env file
   python3 setup_datastream.py
   
   # Optionally, you can override the values:
   python3 setup_datastream.py --cloud-id "your_cloud_id_here" --api-key "your_api_key_here"
   ```

7. **Place your syslog files in the `logs` directory**
   ```bash
   cp /path/to/your/syslog/files/*.log logs/
   ```

8. **Start the containers**
   ```bash
   docker-compose up -d
   ```

## Directory Structure

```
.
├── docker-compose.yml
├── .env
├── logstash.yml                  # Logstash main configuration template
├── logs/                         # Place your syslog files here
├── logstash/
│   ├── config/
│   │   └── logstash.yml          # Logstash main configuration (mounted)
│   ├── pipeline/
│   │   └── syslog-pipeline.conf  # Logstash pipeline configuration
│   └── secrets/                  # For any sensitive files
├── requirements.txt              # Python dependencies
├── setup_datastream.py           # Python script to create Elasticsearch data stream
├── setup.sh                      # Setup script
├── download_logs.sh              # Bash script to download sample logs
├── download_logs.py              # Python script to download sample logs
└── Advanced_Character_Encoding_Handling.md # Guide for handling encoding issues
```

## Monitoring

You can check Logstash's status at `http://localhost:9600`.

## Customization

- To modify the parsing pattern, edit the `grok` filter in `syslog-pipeline.conf`.
- To adjust system resources, modify the `LS_JAVA_OPTS` in `docker-compose.yml`.
- For debugging, uncomment the `stdout` output in `syslog-pipeline.conf`.

## Troubleshooting

**Issue**: Logstash is not picking up new files.
**Solution**: Verify file permissions and restart Logstash.
```bash
docker-compose restart logstash
```

**Issue**: Connection to Elasticsearch fails.
**Solution**: Verify your cloud ID and API key in the `.env` file.

**Issue**: Character encoding warnings in logs.
**Solution**: The pipeline includes a Ruby filter to handle encoding issues by converting non-UTF-8 characters to question marks. This preserves potentially important security information while ensuring compatibility with Elasticsearch. If you need different handling, you can modify the Ruby filter in the pipeline configuration.
