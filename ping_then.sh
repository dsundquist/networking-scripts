#!/bin/bash

# Check if target argument is provided
if [ -z "$1" ]; then
    echo "Usage: $0 <target> [threshold_ms]"
    echo "Example: $0 google.com 100"
    exit 1
fi

TARGET="$1"
THRESHOLD="${2:-100}"

# Create log file with timestamp in same directory as script
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
DATESTAMP=$(date +"%Y%m%d_%H%M%S")
LOGFILE="${SCRIPT_DIR}/ping_then_${TARGET}_${DATESTAMP}.log"

# Function to log to both console and file
log() {
    echo "$1" | tee -a "$LOGFILE"
}

# Function to get current timestamp in UTC
get_time() {
    date -u +"%Y-%m-%d %H:%M:%S UTC"
}

log "Monitoring $TARGET - Will traceroute when latency > ${THRESHOLD}ms or no response (timestamps in UTC)"
log "Press Ctrl+C to stop..."
log ""
log "Log file: $LOGFILE"
log ""
log "Sending initial ping (ignoring result)..."

# Send one initial ping and ignore the result (warm-up)
ping -c 1 "$TARGET" >/dev/null 2>&1

log "Starting monitoring..."
log ""

while true; do
    # Ping once and capture output
    ping_output=$(ping -c 1 -t 5 "$TARGET" 2>&1)
    ping_exit_code=$?
    
    # Check for ping failure (timeout, unreachable, etc.)
    if [ $ping_exit_code -ne 0 ]; then
        timestamp=$(get_time)
        log "[$timestamp] No response from $TARGET"
        log "Running traceroute..."
        traceroute "$TARGET" 2>&1 | while IFS= read -r line; do
            log "$line"
        done
        log ""
        sleep 1
        continue
    fi
    
    # Extract latency from ping output (macOS format: time=X.XXX ms)
    latency=$(echo "$ping_output" | grep -oE 'time=[0-9]+\.?[0-9]*' | head -1 | cut -d'=' -f2)
    
    if [ -n "$latency" ]; then
        # Convert to integer for comparison (truncate decimal)
        latency_int=${latency%.*}
        
        # Handle sub-millisecond case
        if [ -z "$latency_int" ] || [ "$latency_int" -eq 0 ]; then
            latency_int=0
        fi
        
        timestamp=$(get_time)
        
        # Compare latency to threshold
        if [ "$latency_int" -gt "$THRESHOLD" ]; then
            log "[$timestamp] High latency detected: ${latency}ms (threshold: ${THRESHOLD}ms)"
            log "Running traceroute..."
            traceroute -n "$TARGET" 2>&1 | while IFS= read -r line; do
                log "$line"
            done
            log ""
        else
            log "[$timestamp] $TARGET - ${latency}ms"
        fi
    fi
    
    # Small delay before next ping
    sleep 1
done
