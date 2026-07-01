#!/usr/bin/env bash
set -euo pipefail

# Usage: sudo ./net-inspect.sh <target-ip>
# Example: sudo ./net-inspect.sh 10.0.2.52

if [[ $# -lt 1 ]]; then
    echo "Usage: $0 <target-ip>"
    exit 1
fi

TARGET="$1"
SUBNET="$(echo "$TARGET" | cut -d. -f1-3).0/24"
IFACE="$(ip route | awk '/default/ {print $5; exit}')"
TIMESTAMP="$(date +%Y%m%d-%H%M%S)"
INSPECT_FILE="inspection-report-${TIMESTAMP}.txt"
PCAP_FILE="capture-${TIMESTAMP}.pcap"

RED_BG='\033[41;30m'
GREEN_BG='\033[42;30m'
RESET='\033[0m'

# Detect distro and set package manager
if command -v apt &>/dev/null; then
    PKG_INSTALL="apt install -y"
    PKG_UPDATE="apt update"
elif command -v dnf &>/dev/null; then
    PKG_INSTALL="dnf install -y"
    PKG_UPDATE="dnf check-update || true"
else
    echo "Unsupported package manager. Exiting."
    exit 1
fi

log() {
    echo ""
    echo "========================================"
    echo "$1"
    echo "========================================"
}

# Intro message
echo ""
echo -e "${RED_BG}  The remote inspection will begin in 5 seconds  ${RESET}"
echo ""
sleep 5

# Install packages
echo "Installing required packages..."
$PKG_UPDATE > /dev/null 2>&1
$PKG_INSTALL nmap fping netcat-openbsd arping tcpdump > /dev/null 2>&1 || \
$PKG_INSTALL nmap fping nmap-ncat iputils tcpdump > /dev/null 2>&1 || true
echo "Packages ready."

# ─────────────────────────────────────────────
# Packet capture — start BEFORE inspection runs
# ─────────────────────────────────────────────
tcpdump -i "$IFACE" host "$TARGET" -w "$PCAP_FILE" > /dev/null 2>&1 &
TCPDUMP_PID=$!
sleep 1

# ─────────────────────────────────────────────
# Inspection report
# ─────────────────────────────────────────────
echo "Running remote inspection of $TARGET..."

{
    log "Inspection Report — $(date)"
    echo "Target:  $TARGET"
    echo "Subnet:  $SUBNET"

    log "nmap — Host discovery on $SUBNET"
    nmap -sn "$SUBNET"

    log "nmap — Open ports on $TARGET"
    nmap -sT "$TARGET"

    log "nmap — Specific ports (22,80,443) across $SUBNET"
    nmap -p 22,80,443 "$SUBNET"

    log "fping — Alive hosts on $SUBNET"
    fping -a -g "$SUBNET" 2>/dev/null || true

    log "nc — Probe ports 22, 80, 443 on $TARGET"
    for port in 22 80 443; do
        nc -zv -w 2 "$TARGET" "$port" 2>&1 || true
    done

    log "arping — Layer 2 discovery of $TARGET"
    arping -c 4 "$TARGET" 2>/dev/null || echo "arping failed — target may not be on local segment"

    log "dig — Reverse DNS lookup of $TARGET"
    dig -x "$TARGET" +short 2>/dev/null || echo "No PTR record found"

} > "$INSPECT_FILE"

# Stop packet capture
kill "$TCPDUMP_PID" 2>/dev/null || true
wait "$TCPDUMP_PID" 2>/dev/null || true

# Exit message
echo ""
echo -e "${GREEN_BG}  Inspection complete!                                      ${RESET}"
echo -e "${GREEN_BG}  Inspection report : $INSPECT_FILE  ${RESET}"
echo -e "${GREEN_BG}  Packet capture    : $PCAP_FILE  ${RESET}"
echo -e "${GREEN_BG}  Read capture with : sudo tcpdump -r $PCAP_FILE  ${RESET}"
echo ""