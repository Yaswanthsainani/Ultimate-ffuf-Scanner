#!/bin/bash

# Ultimate FFUF Scanner with Slack Integration
# Version 13.1 - Optimized File Structure and Clean Reporting
# Modified to store only scan.log, target.json, and clean_results.txt in structured directories

# Configuration
WORDLIST="/root/tools/wordlists/super.txt"
OUTPUT_DIR="/root/automation/fuzz/fuzzresults"
USER_AGENT="Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36"
SLACK_WEBHOOK="https://hooks.slack.com/services/"  # Replace with your webhook

# Scan Settings
THREADS=40
TIMEOUT=10
STATUS_CODES="200,302"
RECURSION_DEPTH=1
MAX_DUPLICATE_SIZE=5  # Remove endpoints if same size appears more than this

# Initialize directory structure based on domain hierarchy
init_scan() {
    TARGET=$(echo "$1" | sed -E 's|^https?://||; s|/.*$||')
    MAIN_DOMAIN=$(get_main_domain "$TARGET")
    SUBDOMAIN=$(echo "$TARGET" | sed 's/[^a-zA-Z0-9._-]/_/g')
    
    # Create directory structure: fuzzresults/maindomain/subdomain/
    DOMAIN_DIR="$OUTPUT_DIR/$MAIN_DOMAIN/$SUBDOMAIN"
    mkdir -p "$DOMAIN_DIR"
    
    # Only these 3 files will be kept
    OUTPUT_FILE="$DOMAIN_DIR/$SUBDOMAIN.json"
    LOG_FILE="$DOMAIN_DIR/scan.log"
    CLEAN_FILE="$DOMAIN_DIR/clean_results.txt"
    
    TEMP_FILE=$(mktemp)  # Temporary file for processing
    
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] Starting scan for $TARGET" >> "$LOG_FILE"
}

# Extract main domain (apple.com from food.apple.com)
get_main_domain() {
    local domain="$1"
    if [[ "$domain" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
        echo "ip_$domain"
    else
        echo "$domain" | awk -F. '{if (NF>=2) print $(NF-1)"."$NF; else print $1}'
    fi
}

# Slack notification with clean results
send_slack() {
    local message="$1"
    local file_path="$2"
    
    [ -z "$SLACK_WEBHOOK" ] && return
    
    if [ -z "$file_path" ]; then
        curl -s -X POST -H 'Content-type: application/json' \
            --data "{\"text\":\"$message\"}" \
            "$SLACK_WEBHOOK" >/dev/null
    else
        # Send both message and clean results file
        curl -s -X POST -H 'Content-type: application/json' \
            --data "{\"text\":\"$message\"}" \
            "$SLACK_WEBHOOK" >/dev/null
        
        curl -s -F file=@"$file_path" \
             -F initial_comment="Clean results for $TARGET" \
             -F channels="#scans" \
             "$SLACK_WEBHOOK" >/dev/null
    fi
}

# Filter results and generate clean output
filter_results() {
    echo -e "\n\033[1;33m[+] Filtering duplicate size endpoints...\033[0m" | tee -a "$LOG_FILE"
    
    # Extract all sizes and count occurrences
    jq -r '.results[] | .length' "$OUTPUT_FILE" | sort | uniq -c > "$TEMP_FILE.size_counts"
    
    # Identify sizes to remove (appearing more than MAX_DUPLICATE_SIZE)
    awk -v threshold="$MAX_DUPLICATE_SIZE" '$1 > threshold {print $2}' "$TEMP_FILE.size_counts" > "$TEMP_FILE.sizes_to_remove"
    
    # Filter original results
    jq --slurpfile sizes "$TEMP_FILE.sizes_to_remove" \
       '.results |= map(select(.length as $size | $sizes[] | index($size) | not)' \
       "$OUTPUT_FILE" > "$TEMP_FILE.filtered"
    
    # Generate clean results
    jq -r '.results[] | "\(.url) [Status: \(.status), Size: \(.length)]"' "$TEMP_FILE.filtered" \
        | sort -u > "$CLEAN_FILE"
    
    # Count results
    result_count=$(wc -l < "$CLEAN_FILE")
    echo -e "\033[1;32m[+] Found $result_count valid paths after filtering\033[0m" | tee -a "$LOG_FILE"
    
    # Clean up temp files
    rm -f "$TEMP_FILE" "$TEMP_FILE.size_counts" "$TEMP_FILE.sizes_to_remove" "$TEMP_FILE.filtered"
}

# Main scanning function
run_scan() {
    local target="$1"
    local protocol="$2"
    
    echo -e "\n\033[1;34m[+] Scanning $protocol://$target\033[0m" | tee -a "$LOG_FILE"
    send_slack "🚀 Starting FFUF scan for $protocol://$target"

    # Run FFUF and capture live output to log
    ffuf -u "$protocol://$target/FUZZ" \
        -w "$WORDLIST" \
        -mc "$STATUS_CODES" \
        -t "$THREADS" \
        -timeout "$TIMEOUT" \
        -recursion -recursion-depth "$RECURSION_DEPTH" \
        -H "User-Agent: $USER_AGENT" \
        -o "$TEMP_FILE" -of json \
        -v 2>&1 | tee -a "$LOG_FILE"
    
    # Process results if scan was successful
    if [ -f "$TEMP_FILE" ] && [ -s "$TEMP_FILE" ]; then
        # Format the output file with scan metadata
        jq '{
            scan_info: {
                target: "'"$protocol://$target"'",
                timestamp: (now | todate),
                wordlist: "'"$WORDLIST"'",
                config: {
                    threads: '"$THREADS"',
                    timeout: '"$TIMEOUT"',
                    matcher: "'"$STATUS_CODES"'"
                }
            },
            results: .results
        }' "$TEMP_FILE" > "$OUTPUT_FILE"
        
        # Filter results and generate clean output
        filter_results
        
        # Send completion notification with clean results
        send_slack "✅ Scan completed for $protocol://$target\nFound $result_count valid paths" "$CLEAN_FILE"
    else
        echo -e "\033[1;31m[!] Scan failed - no output created\033[0m" | tee -a "$LOG_FILE"
        send_slack "❌ Scan failed for $protocol://$target"
    fi
}

# Main execution
echo -e "╔════════════════════════════════════╗"
echo -e "║   Ultimate FFUF Scanner v13.1                 ║"
echo -e "║                                --YASH         ║"
echo -e "╚════════════════════════════════════╝"


read -p "Enter target (domain/IP) or path to domain list: " input

if [ -f "$input" ]; then
    echo -e "\033[1;32m[+] Processing domain list: $input\033[0m"
    while IFS= read -r line || [[ -n "$line" ]]; do
        line=$(echo "$line" | xargs)
        [ -z "$line" ] && continue
        
        init_scan "$line"
        
        if curl -s -I -A "$USER_AGENT" --connect-timeout 5 "https://$TARGET" >/dev/null 2>&1; then
            run_scan "$TARGET" "https"
        elif curl -s -I -A "$USER_AGENT" --connect-timeout 5 "http://$TARGET" >/dev/null 2>&1; then
            echo -e "\033[1;33m[~] HTTPS failed, trying HTTP\033[0m" | tee -a "$LOG_FILE"
            run_scan "$TARGET" "http"
        else
            echo -e "\033[1;31m[!] Target unreachable: $TARGET\033[0m" | tee -a "$LOG_FILE"
            send_slack "❌ Target unreachable: $TARGET"
        fi
    done < "$input"
else
    init_scan "$input"
    if curl -s -I -A "$USER_AGENT" --connect-timeout 5 "https://$TARGET" >/dev/null 2>&1; then
        run_scan "$TARGET" "https"
    elif curl -s -I -A "$USER_AGENT" --connect-timeout 5 "http://$TARGET" >/dev/null 2>&1; then
        echo -e "\033[1;33m[~] HTTPS failed, trying HTTP\033[0m" | tee -a "$LOG_FILE"
        run_scan "$TARGET" "http"
    else
        echo -e "\033[1;31m[!] Target unreachable: $TARGET\033[0m" | tee -a "$LOG_FILE"
        send_slack "❌ Target unreachable: $TARGET"
    fi
fi

echo -e "\n\033[1;32m[+] All scans completed!\033[0m"
echo -e "Clean results saved to respective target directories in: $OUTPUT_DIR"