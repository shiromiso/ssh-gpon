#!/usr/bin/env bash
set -euo pipefail

UDR_USER="root"

# Optional dotfile holding the GPON SSH password (first line is used).
# Override the location with the SSH_GPON_PASS_FILE environment variable.
PASS_FILE="${SSH_GPON_PASS_FILE:-${HOME}/.ssh-gpon}"

if [[ $# -ne 1 ]]; then
cat <<'EOF'
============================================================
 Nokia G-010S-A GPON status
============================================================

This script will:
  SSH to UniFi
  Set up a temp IP address on GPON interface
  SSH to GPON
  Read diagnostics
  Remove temp IP when done
============================================================
EOF

echo
echo "Usage: $0 <UniFi-IP>" >&2

exit 1
fi

UDR_HOST="$1"

# Command to run on the GPON (quoted here-doc keeps the body literal).
REMOTE_CMD="$(cat <<'REMOTE_EOF'
cat <<'EOF'
Normal status:
  5 - Link operational and registered
Other status:
  1 - No usable optical signal; check fiber
  2 - Optical signal detected; awaiting activation
  3 - ONU identification/authentication in progress
  4 - Timing and distance calibration in progress
  6 - Temporary loss of synchronization/recovery
  7 - ONU disabled by the OLT; transmitter stopped
EOF

echo
/opt/lantiq/bin/onu ploamsg

echo
tail -n 1 /proc/driver/optic/temperatures |
tr -d '[],' |
awk '{printf "Die: %.1f C\nLaser: %.1f C\n", $2-273.15, $3-273.15}'
REMOTE_EOF
)"

# Base64-encode to survive both shells intact
REMOTE_CMD_B64="$(printf '%s' "${REMOTE_CMD}" | base64 | tr -d '\n')"

# If the dotfile exists, take the GPON password from it
# Otherwise, the user is prompted interactively
GPON_PASS_B64=""
if [[ -f "${PASS_FILE}" ]]; then
    GPON_PASS="$(head -n 1 "${PASS_FILE}")"
    if [[ -n "${GPON_PASS}" ]]; then
        echo "Using GPON password from ${PASS_FILE}"
        GPON_PASS_B64="$(printf '%s' "${GPON_PASS}" | base64 | tr -d '\n')"
    fi
    unset GPON_PASS
fi

echo "Connecting to UniFi at ${UDR_HOST}"

ssh -tt "${UDR_USER}@${UDR_HOST}" '
set -eu

IFACE="eth4"
TEMP_CIDR="192.168.1.2/24"
GPON_IP="192.168.1.10"
GPON_USER="ONTUSER"
GPON_PASS_B64='"'${GPON_PASS_B64}'"'
REMOTE_CMD_B64='"'${REMOTE_CMD_B64}'"'

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

REMOTE_CMD="$(printf "%s" "${REMOTE_CMD_B64}" | base64 -d)"

# GPON firmware regenerates its SSH host key on every reboot.
if [ -n "${GPON_PASS_B64}" ]; then
    GPON_PASS="$(printf "%s" "${GPON_PASS_B64}" | base64 -d)"

    sshpass -p "${GPON_PASS}" ssh \
        -oStrictHostKeyChecking=no \
        -oUserKnownHostsFile=/dev/null \
        -oKexAlgorithms=+diffie-hellman-group1-sha1 \
        -oHostKeyAlgorithms=+ssh-rsa \
        "${GPON_USER}@${GPON_IP}" "${REMOTE_CMD}"
    exit 0
fi

echo "Connecting to GPON at ${GPON_IP} (default password: SUGAR2A041)"

ssh \
    -oStrictHostKeyChecking=no \
    -oUserKnownHostsFile=/dev/null \
    -oKexAlgorithms=+diffie-hellman-group1-sha1 \
    -oHostKeyAlgorithms=+ssh-rsa \
    "${GPON_USER}@${GPON_IP}" "${REMOTE_CMD}"
'
