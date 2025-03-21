#!/usr/bin/env python3
import os
import sys
import requests
import tarfile
from tqdm import tqdm
import concurrent.futures

# URLs for the log files
URLS = [
    "https://zenodo.org/records/8196385/files/Windows.tar.gz?download=1",
    "https://zenodo.org/records/8196385/files/Linux.tar.gz?download=1",
    "https://zenodo.org/records/8196385/files/Mac.tar.gz?download=1"
]

# Output directory
OUTPUT_DIR = "logs"

def download_file(url):
    """
    Download a file from a URL with progress bar
    """
    # Get the filename from the URL
    filename = url.split('/')[-1].split('?')[0]
    output_path = os.path.join(OUTPUT_DIR, filename)
    
    print(f"Downloading {filename}...")
    
    # Stream the download with progress bar
    response = requests.get(url, stream=True)
    total_size = int(response.headers.get('content-length', 0))
    block_size = 1024  # 1 Kibibyte
    
    with open(output_path, 'wb') as file, tqdm(
            desc=filename,
            total=total_size,
            unit='iB',
            unit_scale=True,
            unit_divisor=1024,
        ) as bar:
        for data in response.iter_content(block_size):
            size = file.write(data)
            bar.update(size)
    
    return output_path

def extract_tarfile(file_path):
    """
    Extract a tar.gz file
    """
    print(f"Extracting {os.path.basename(file_path)}...")
    with tarfile.open(file_path, "r:gz") as tar:
        tar.extractall(path=OUTPUT_DIR)
    print(f"Extracted {os.path.basename(file_path)}")

def main():
    # Create output directory if it doesn't exist
    if not os.path.exists(OUTPUT_DIR):
        os.makedirs(OUTPUT_DIR)
        print(f"Created directory: {OUTPUT_DIR}")
    
    downloaded_files = []
    
    # Download files sequentially with progress bars
    for url in URLS:
        try:
            file_path = download_file(url)
            downloaded_files.append(file_path)
        except Exception as e:
            print(f"Error downloading {url}: {e}")
    
    print("\nAll downloads completed.")
    
    # Extract files in parallel for better performance
    print("\nExtracting files...")
    with concurrent.futures.ThreadPoolExecutor(max_workers=3) as executor:
        executor.map(extract_tarfile, downloaded_files)
    
    print("\nAll files have been downloaded and extracted to the 'logs' directory.")
    print("You can now run Logstash to process these log files.")
    
    # Uncomment to remove the tar.gz files after extraction
    # print("\nCleaning up archive files...")
    # for file_path in downloaded_files:
    #     os.remove(file_path)
    #     print(f"Removed {os.path.basename(file_path)}")

if __name__ == "__main__":
    main()