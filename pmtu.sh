#!/bin/bash

# Check if the user provided the destination as an argument
if [ "$#" -ne 1 ]; then
    echo "Usage: $0 <destination>"
    exit 1
fi

destination=$1
min_size=1000  # Minimum packet size to check
step_size=10   # Step size to decrease the packet size
#timeout=500      # Timeout for each ping (in seconds)
interface_mtu=0

# Detect if the destination is IPv6 (contains ':')
if [[ "$destination" == *:* ]]; then
    max_size=1460
    ping_cmd="ping6"
    timeout_flag=""  # Linux supports -W but mac doesn't. TODO: Support this
    header_size=40   # IPv6 header is 40 bytes
else
    ping_cmd="ping"
    max_size=1472
    timeout_flag="-W 500"
    header_size=28   # IPv4 header is 28 bytes
fi

# Start from the max_size and work down
for ((size=max_size; size>=min_size; size-=step_size)); do
    echo "Pinging $destination with $ping_cmd and a packet size of $size..."

    # Ping the destination with appropriate flags
    $ping_cmd -D -c 1 -s $size $timeout_flag $destination > /dev/null 2>&1

    # Check if the ping was successful
    if [ $? -eq 0 ]; then
        interface_mtu=$((size + header_size))  # Add header size for IP/ICMP header
        echo "Success: Path MTU found to be $interface_mtu bytes"
        break
    else
        echo "Packet size $size failed."
    fi
done

# If no successful ping was found
if [ $interface_mtu -eq 0 ]; then
    echo "No suitable Path MTU found for destination $destination in the range."
else
    echo "Final Path MTU for $destination: $interface_mtu bytes."
fi