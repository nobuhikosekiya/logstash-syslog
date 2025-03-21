# Elasticsearch API Key Setup Instructions

This project requires two different API keys with different permission levels:

## 1. Admin API Key (ELASTIC_ADMIN_API_KEY)

The admin API key is used by the Python setup script to create the data stream and index template.

### Required Permissions:
- `manage_index_templates` privilege
- `manage` privilege on data streams
- `create_index` privilege

### How to Create an Admin API Key:

1. In Kibana, go to **Stack Management** → **Security** → **API Keys**
2. Click **Create API key**
3. Provide a name, e.g., "Syslog-Admin-Key"
4. Add the following role descriptors:

```json
{
  "setup_role": {
    "cluster": ["manage_index_templates"],
    "indices": [
      {
        "names": ["logs-syslog-*"],
        "privileges": ["manage", "create_index"]
      }
    ]
  }
}
```

5. Click **Create**
6. Copy the generated API key and add it to the `.env` file as `ELASTIC_ADMIN_API_KEY`

## 2. Logstash API Key (ELASTIC_LOGSTASH_API_KEY)

This key is used by Logstash to write data to the data stream.

### Required Permissions:
- `auto_configure` privilege on the data stream
- `write` privilege on the data stream

### How to Create a Logstash API Key:

1. In Kibana, go to **Stack Management** → **Security** → **API Keys**
2. Click **Create API key**
3. Provide a name, e.g., "Syslog-Logstash-Key"
4. Add the following role descriptors:

```json
{
  "ingest_role": {
    "cluster": [],
    "indices": [
      {
        "names": ["logs-syslog-default"],
        "privileges": ["auto_configure", "write"]
      }
    ]
  }
}
```

5. Click **Create**
6. Copy the generated API key and add it to the `.env` file as `ELASTIC_LOGSTASH_API_KEY`

## Important Notes

1. The API keys should be generated with the minimum necessary permissions for security best practices.
2. Both keys should be kept secure and never shared or committed to version control.
3. API keys can be deleted or invalidated if you need to rotate them.
