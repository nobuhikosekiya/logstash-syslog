#!/usr/bin/env python3
import os
import argparse
import sys
from elasticsearch import Elasticsearch
from dotenv import load_dotenv

def load_env_variables():
    """
    Load environment variables from .env file
    """
    load_dotenv()
    
    cloud_id = os.environ.get('ELASTIC_CLOUD_ID')
    api_key = os.environ.get('ELASTIC_ADMIN_API_KEY')
    
    if not cloud_id or not api_key:
        raise ValueError("ELASTIC_CLOUD_ID and ELASTIC_ADMIN_API_KEY must be set in the .env file")
    
    return cloud_id, api_key

def create_es_client(cloud_id, api_key):
    """
    Create an Elasticsearch client using the provided cloud_id and api_key
    """
    client = Elasticsearch(
        cloud_id=cloud_id,
        api_key=api_key
    )
    
    # Check if connection was successful
    if not client.ping():
        raise ConnectionError("Could not connect to Elasticsearch. Please check your credentials.")
    
    return client

def check_datastream_exists(client, data_stream_name):
    """
    Check if a data stream already exists
    """
    try:
        return client.indices.get_data_stream(name=data_stream_name)["data_streams"] != []
    except:
        return False

def create_index_template(client, template_name, data_stream_name, index_pattern):
    """
    Create an index template for the data stream
    """
    template = {
        "index_patterns": [index_pattern],
        "data_stream": {},
        "priority": 500,
        "template": {
            "settings": {
                "number_of_shards": 1,
                "number_of_replicas": 1
            },
            "mappings": {
                "properties": {
                    "@timestamp": {"type": "date"},
                    "host.name": {"type": "keyword"},
                    "message": {"type": "text"}
                }
            }
        }
    }
    
    try:
        response = client.indices.put_index_template(name=template_name, body=template)
        if response.get("acknowledged"):
            print(f"Index template '{template_name}' created successfully")
        else:
            print(f"Failed to create index template: {response}")
            sys.exit(1)
    except Exception as e:
        print(f"Error creating index template: {str(e)}")
        sys.exit(1)

def create_datastream(client, data_stream_name):
    """
    Create a data stream
    """
    try:
        response = client.indices.create_data_stream(name=data_stream_name)
        print(f"Data stream '{data_stream_name}' created successfully")
    except Exception as e:
        print(f"Error creating data stream: {str(e)}")
        sys.exit(1)

def main():
    parser = argparse.ArgumentParser(description='Set up Elasticsearch data stream for Logstash syslog ingestion')
    parser.add_argument('--type', dest='type', help='Data stream type', default='logs')
    parser.add_argument('--dataset', dest='dataset', help='Data stream dataset', default='syslog')
    parser.add_argument('--namespace', dest='namespace', help='Data stream namespace', default='default')
    parser.add_argument('--cloud-id', dest='cloud_id', help='Elasticsearch Cloud ID (overrides .env)', default=None)
    parser.add_argument('--api-key', dest='api_key', help='Elasticsearch API Key (overrides .env)', default=None)
    
    args = parser.parse_args()
    
    try:
        # Try to load from .env first
        cloud_id, api_key = load_env_variables()
        
        # Override with command line if provided
        if args.cloud_id:
            cloud_id = args.cloud_id
        if args.api_key:
            api_key = args.api_key
        
        # Create Elasticsearch client
        client = create_es_client(cloud_id, api_key)
        
        # Construct the data stream name (format: {type}-{dataset}-{namespace})
        data_stream_name = f"{args.type}-{args.dataset}-{args.namespace}"
        template_name = f"{args.type}-{args.dataset}-template"
        index_pattern = f"{args.type}-{args.dataset}-*"
        
        # Check if data stream already exists
        if check_datastream_exists(client, data_stream_name):
            print(f"Data stream '{data_stream_name}' already exists")
        else:
            # Create index template first (required for data streams)
            create_index_template(client, template_name, data_stream_name, index_pattern)
            
            # Create the data stream
            create_datastream(client, data_stream_name)
        
        print("Setup completed successfully!")
        
    except Exception as e:
        print(f"Error: {str(e)}")
        sys.exit(1)

if __name__ == "__main__":
    main()