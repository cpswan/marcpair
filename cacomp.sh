#!/bin/bash

LOCAL_FILE="cacert.pem"
REMOTE_FILE="cacert_latest.pem"
REMOTE_URL="https://curl.se/ca/cacert.pem"

# 1. Download
echo "Downloading latest CA bundle..."
curl -s -o "$REMOTE_FILE" "$REMOTE_URL"

# 2. Function to extract Certs and their "Mozilla-style" names
extract_with_names() {
    local input=$1
    local output=$2
    local last_line=""
    local second_to_last=""

    while IFS= read -r line; do
        # If we hit the start of a cert, the name was 2 lines ago
        if [[ "$line" == *"-----BEGIN CERTIFICATE-----"* ]]; then
            echo "$line" > current.tmp
            
            # Continue reading until the end of this specific cert
            while IFS= read -r inner_line; do
                echo "$inner_line" >> current.tmp
                [[ "$inner_line" == *"-----END CERTIFICATE-----"* ]] && break
            done
            
            # Get fingerprint and pair it with the captured name
            fp=$(openssl x509 -noout -fingerprint -sha256 -in current.tmp 2>/dev/null)
            if [[ -n "$fp" ]]; then
                # $second_to_last is the CA Name
                # $last_line is the ======= line
                echo "$fp | $second_to_last" >> "$output"
            fi
            rm current.tmp
        fi
        second_to_last="$last_line"
        last_line="$line"
    done < "$input"
    
    sort -u -o "$output" "$output"
}

echo "Mapping certificates (Local)..."
> local_map.txt
extract_with_names "$LOCAL_FILE" "local_map.txt"

echo "Mapping certificates (Remote)..."
> remote_map.txt
extract_with_names "$REMOTE_FILE" "remote_map.txt"

# 3. Final Comparison
echo -e "\n--- DISCREPANCY REPORT ---"

# This finds lines in local_map that do NOT exist in remote_map
# (Checks the whole string: "Fingerprint | Name")
comm -23 local_map.txt remote_map.txt > differences.txt

if [ ! -s differences.txt ]; then
    echo "[✓] No differences found. Your local certs match Mozilla's records."
else
    echo "[!] The following certs are in your LOCAL file but MISSING from Mozilla:"
    echo "----------------------------------------------------------------------"
    cat differences.txt
fi

# Clean up
rm local_map.txt remote_map.txt differences.txt "$REMOTE_FILE"