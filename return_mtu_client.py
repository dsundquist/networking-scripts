# Client script: Run this on the client machine
# Save as return_mtu_client.py
# Usage: python return_mtu_client.py <server_ip> [port] (default 12345)

import socket
import sys
import time

SERVER_IP = sys.argv[1]
PORT = int(sys.argv[2]) if len(sys.argv) > 2 else 54162
MIN_SIZE = 500
MAX_SIZE = 9000
HEADER_OVERHEAD = 28  # Approximate IP + UDP headers (20 + 8)
TRIES = 3
TIMEOUT = 2  # seconds

def probe_size(sock, size):
    sock.sendto(f"probe {size}".encode('utf-8'), (SERVER_IP, PORT))
    sock.settimeout(TIMEOUT)
    for _ in range(TRIES):
        try:
            data, _ = sock.recvfrom(9000 + 100)  # Buffer large enough
            if len(data) == size:
                return True
        except socket.timeout:
            continue
    return False

sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)

print(f"Testing return path MTU from {SERVER_IP} (binary search {MIN_SIZE}-{MAX_SIZE} bytes payload)...")

low = MIN_SIZE
high = MAX_SIZE
while low < high:
    mid = (low + high + 1) // 2
    print(f"Probing size {mid}...")
    if probe_size(sock, mid):
        low = mid
    else:
        high = mid - 1

pmtu = low + HEADER_OVERHEAD
print(f"\nLargest successful response payload: {low} bytes")
print(f"Estimated return path MTU: {pmtu} bytes")
