#!/bin/bash

LOCAL_FILE="cacert.pem"
REMOTE_FILE="cacert_latest.pem"
REMOTE_URL="https://curl.se/ca/cacert.pem"

# 1. Download
echo "Downloading latest CA bundle..."
curl -s -o "$REMOTE_FILE" "$REMOTE_URL"

# 2. Function to create a clean "Fingerprint Name" map
create_map() {
    local input=$1
    local output=$2
    
    # This loop identifies the block, extracts the name 2 lines above the BEGIN tag,
    # and pairs it with the SHA256 fingerprint.
    csplit -s -z "$input" '/BEGIN CERTIFICATE/' '{*}' -f "temp_cert_"
    
    for f in temp_cert_*; do
        # Extract the label (the line above the ===)
        # We look for the line preceding the "======" line
        label=$(grep -B 2 "BEGIN CERTIFICATE" "$f" | head -n 1 | tr -d '\r')
        
        # Get fingerprint
        fp=$(openssl x509 -noout -fingerprint -sha256 -in "$f" 2>/dev/null)
        
        if [ ! -z "$fp" ]; then
            echo "$fp | $label" >> "$output"
        fi
        rm "$f"
    done
    
    # Sort for comparison
    sort -o "$output" "$output"
}

echo "Processing local and remote certificates..."
> local_map.txt
> remote_map.txt
create_map "$LOCAL_FILE" "local_map.txt"
create_map "$REMOTE_FILE" "remote_map.txt"

# 3. Compare
echo -e "\n--- DISCREPANCY REPORT ---"

# We compare based on the fingerprint (Column 1)
awk -F' | ' 'NR==FNR{remote[$1]; next} !($1 in remote)' remote_map.txt local_map.txt > differences.txt

if [ ! -s differences.txt ]; then
    echo "[✓] Your subset is 100% valid against the latest Mozilla bundle."
else
    echo "[!] The following CA(s) in your local file are MISSING or CHANGED in the Mozilla bundle:"
    echo "--------------------------------------------------------------------------------"
    cat differences.txt
fi

# Clean up
rm local_map.txt remote_map.txt differences.txt "$REMOTE_FILE"