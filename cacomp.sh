#!/bin/bash

# Configuration
LOCAL_FILE="cacert.pem"
REMOTE_URL="https://curl.se/ca/cacert.pem"
REMOTE_FILE="cacert_latest.pem"

# 1. Download the latest Mozilla bundle
echo "Downloading latest CA bundle from curl.se..."
curl -s -o "$REMOTE_FILE" "$REMOTE_URL"

if [ $? -ne 0 ]; then
    echo "Error: Failed to download the remote file."
    exit 1
fi

# Function to extract fingerprints from a pem file
get_fingerprints() {
    # Splits the bundle into individual certs and calculates SHA256 fingerprint
    awk '/BEGIN CERTIFICATE/,/END CERTIFICATE/' "$1" | \
    awk 'split_after==1{n++;split_after=0} /END CERTIFICATE/{split_after=1} {print > "cert" n ".tmp"}'
    
    for f in cert*.tmp; do
        openssl x509 -noout -fingerprint -sha256 -in "$f" 2>/dev/null
        rm "$f"
    done | sort
}

echo "Analyzing certificates..."

# 2. Generate fingerprint lists
get_fingerprints "$LOCAL_FILE" > local_hashes.txt
get_fingerprints "$REMOTE_FILE" > remote_hashes.txt

# 3. Compare using 'diff' or 'comm'
echo "--- Comparison Results ---"

# Find certs in your local file that are NOT in the remote file (Outdated/Custom)
COMM_OUT=$(comm -23 local_hashes.txt remote_hashes.txt)

if [ -z "$COMM_OUT" ]; then
    echo "[✓] All local certificates are still present in the Mozilla bundle."
else
    echo "[!] The following fingerprints in your local file are MISSING from the remote bundle:"
    echo "$COMM_OUT"
fi

# Clean up
rm local_hashes.txt remote_hashes.txt "$REMOTE_FILE"