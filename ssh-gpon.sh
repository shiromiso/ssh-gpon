#!/usr/bin/env bash
set -euo pipefail

cat <<'EOF'
============================================================
 Nokia G-010S-A GPON diag
============================================================

This script will:
  SSH to UniFi
  Set up a temp IP address on GPON interface
  SSH to GPON
  Remove temp IP when done

To query link status:
  onu ploamsg

Read "curr_state" value.

Normal status:
  5 - Link operational and registered
Other status:
  1 - No usable optical signal; check fiber
  2 - Optical signal detected; awaiting activation
  3 - ONU identification/authentication in progress
  4 - Timing and distance calibration in progress
  6 - Temporary loss of synchronization/recovery
  7 - ONU disabled by the OLT; transmitter stopped

For more info, refer to this excellent repo:
  https://github.com/hwti/G-010S-A
============================================================
EOF

UDR_USER="root"

if [[ $# -ne 1 ]]; then
    echo "Usage: $0 <UniFi-IP>" >&2
    exit 1
fi

UDR_HOST="$1"

echo "Connecting to UniFi at ${UDR_HOST}"

ssh -tt "${UDR_USER}@${UDR_HOST}" '
set -eu

IFACE="eth4"
TEMP_CIDR="192.168.1.2/24"
GPON_IP="192.168.1.10"
GPON_USER="ONTUSER"

cleanup() {
    echo
    echo "Removing temporary address ${TEMP_CIDR} on ${IFACE}"
    ip addr del "${TEMP_CIDR}" dev "${IFACE}" 2>/dev/null || true
}

trap cleanup EXIT HUP INT TERM

# Ensure a clean state, then add the temporary address.
echo "Adding temporary address ${TEMP_CIDR} on ${IFACE}"
ip addr del "${TEMP_CIDR}" dev "${IFACE}" 2>/dev/null || true
ip addr add "${TEMP_CIDR}" dev "${IFACE}"

echo "Connecting to GPON at ${GPON_IP} (default password: SUGAR2A041)"

ssh -tt \
    -oKexAlgorithms=+diffie-hellman-group1-sha1 \
    -oHostKeyAlgorithms=+ssh-rsa \
    "${GPON_USER}@${GPON_IP}"
'
