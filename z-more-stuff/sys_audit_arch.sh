#!/bin/bash

# Ensure the script is run with sudo if needed for certain commands
if [ "$EUID" -ne 0 ]; then
  echo "⚠️ Warning: Some commands (like pacman, lshw, journalctl) require root privileges."
  echo "It is highly recommended to run this script with sudo: sudo ./sys_audit_arch.sh"
  echo "------------------------------------------------------------------------"
fi

# Define the output file
OUTPUT_FILE="system_report.md"

# Dynamically fetch the computer name and primary local IP address
COMPUTER_NAME=$(hostname)
IP_ADDRESS=$(ip route get 1.1.1.1 2>/dev/null | awk '{print $7}' || hostname -I | awk '{print $1}')

# Clear or initialize the file with a title, system metadata, and date
echo "# System Analytical Report (Arch Linux)" > "$OUTPUT_FILE"
echo "Created on the Linux system: **$COMPUTER_NAME** at **$IP_ADDRESS**" >> "$OUTPUT_FILE"
echo "Generated on: $(date)" >> "$OUTPUT_FILE"
echo "" >> "$OUTPUT_FILE"

# Helper function to append sections cleanly
append_section() {
  local heading="$1"
  local cmd="$2"
  
  echo "## $heading" >> "$OUTPUT_FILE"
  echo "Command: \`$cmd\`" >> "$OUTPUT_FILE"
  echo "\`\`\`text" >> "$OUTPUT_FILE"
  
  # Execute the command and handle errors gracefully
  eval "$cmd" 2>&1 >> "$OUTPUT_FILE"
  
  echo "\`\`\`" >> "$OUTPUT_FILE"
  echo "" >> "$OUTPUT_FILE"
}

echo "⌛ Gathering system analytics... please wait."

# --- OS Version & Distro Info ---
append_section "OS Release Info" "cat /etc/os-release"
append_section "Hostname Control" "hostnamectl"
append_section "System Uptime" "uptime"
append_section "Kernel Architecture" "uname -a"

# --- Networking ---
append_section "Network Interfaces" "ip -br a"
append_section "Routing Table" "ip r"
append_section "Listening Ports" "ss -tulnw"
append_section "Internet Connectivity Test" "ping -c 3 1.1.1.1"

# --- Services & Packages (Arch Modifications Here) ---
append_section "Systemd Service Status" "systemctl status --no-pager | head -n 7"
append_section "Failed Systemd Services" "systemctl --failed --no-pager"
append_section "Pacman Package Integrity Check" "pacman -Qk"         # Changed from apt-get check
append_section "Pacman Database Audit" "pacman -D --check"     # Changed from dpkg --audit

# --- Hardware & CPU ---
append_section "Block Devices" "lsblk"
append_section "CPU Architecture" "lscpu"
append_section "Hardware Summary" "lshw -short 2>/dev/null || echo 'lshw not installed'"
append_section "PCI Devices" "lspci -tv"

# --- Memory & Disk Space ---
append_section "Memory Usage" "free -h"
append_section "Disk Space Usage" "df -h"
append_section "Top-Level Directory Sizes" "du -sh /* 2>/dev/null | sort -rh"

# --- User Information ---
append_section "Current User" "whoami"
append_section "Active User Sessions" "w"
append_section "Recent Login History" "last -a | head -n 20"
append_section "Sudo Privileges" "sudo -l"

# --- Logs ---
append_section "System Error Logs" "journalctl -p 3 -xb --no-pager"

echo "✅ Done! Report saved to: $OUTPUT_FILE"
