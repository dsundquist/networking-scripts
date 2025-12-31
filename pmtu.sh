#!/bin/bash

# Check if the user provided the destination as an argument
if [ "$#" -ne 1 ]; then
    echo "Usage: $0 <destination>"
    exit 1
fi

destination=$1
max_size=1472  # Starting size (1500 MTU minus 28-byte header)
min_size=1000  # Minimum packet size to check
step_size=10   # Step size to decrease the packet size
timeout=1      # Timeout for each ping (in seconds)
interface_mtu=0

# Start from the max_size and work down
for ((size=max_size; size>=min_size; size-=step_size)); do
    echo "Pinging $destination with packet size $size..."
    
    # Ping the destination with a timeout (-W), "Do Not Fragment" bit (-D), and 1 packet (-c 1)
    ping -D -c 1 -s $size -W $timeout $destination > /dev/null 2>&1

    # Check if the ping was successful
    if [ $? -eq 0 ]; then
        interface_mtu=$((size + 28))  # Add 28 bytes for the IP/ICMP header
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

