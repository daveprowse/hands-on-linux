#!/usr/bin/env bash
set -euo pipefail

TIMESTAMP="$(date +%Y%m%d-%H%M%S)"
LOCAL_FILE="report-local-stats-${TIMESTAMP}.txt"

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
echo -e "${RED_BG}  Local stats collection will begin in 5 seconds  ${RESET}"
echo ""
sleep 5

echo "Installing required packages..."
$PKG_UPDATE > /dev/null 2>&1
$PKG_INSTALL iproute2 lsof > /dev/null 2>&1 || true
echo "Packages ready."

echo "Collecting local stats..."

{
    log "Local Stats Report — $(date)"
    echo "Hostname:  $(hostname)"
    echo "Interface: $(ip route | awk '/default/ {print $5; exit}')"

    log "ip a — Interface addresses"
    ip a

    log "ip neigh — ARP neighbor table"
    ip neigh

    log "ip route — Routing table"
    ip route

    log "ss — Listening TCP sockets"
    ss -tlnp

    log "ss — All TCP socket states"
    ss -tan

    log "ss — Socket state summary"
    ss -tan | awk '{print $1}' | sort | uniq -c


    log "lsof — Sockets owned by sshd"
    lsof -i -a -p "$(pgrep sshd | head -1)" 2>/dev/null || echo "sshd not running"

} > "$LOCAL_FILE"

# Exit message
echo ""
echo -e "${GREEN_BG}  Local stats collection complete!               ${RESET}"
echo -e "${GREEN_BG}  Local stats saved to: $LOCAL_FILE  ${RESET}"
echo ""