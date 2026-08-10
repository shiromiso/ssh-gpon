#!/usr/bin/env bash
set -e

HOST="$1"
SRC="$2"
MAC="$3"

ssh "root@$HOST" python3 - "$SRC" "$MAC" <<'PY'
import ipaddress
import socket
import subprocess
import sys

src, mac = sys.argv[1:]

for line in subprocess.check_output(
    ["ip", "-o", "-4", "addr", "show"], text=True
).splitlines():
    cidr = line.split()[3]
    if cidr.split("/")[0] == src:
        bcast = str(ipaddress.ip_interface(cidr).network.broadcast_address)
        break
else:
    raise SystemExit(f"Source IP not found: {src}")

mac = bytes.fromhex(mac.replace(":", ""))
packet = b"\xff" * 6 + mac * 16

s = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
s.setsockopt(socket.SOL_SOCKET, socket.SO_BROADCAST, 1)
s.bind((src, 0))
s.sendto(packet, (bcast, 9))

print(f"Sent WoL to {sys.argv[2]} via {src} -> {bcast}")
PY
