# Appendix X1 — Basic System Auditing

When I sit down to a Linux system that I have not worked at yet I like to run a variety of commands to gather information about that system. 😎

This document shows each of those commands and provides a Bash script that will run all of them (minus `top`) and save a summary markdown file. ❣️

## Commands

Here's the list of commands for a Debian system check:

- `cat /etc/os-release`
- `hostnamectl`
- `uptime`
- `uname -a`
- `ip -br -c a && ip -c r`
- `ss -tulnw`
- `ping -c 3 1.1.1.1`
- `systemctl status`
- `sudo apt-get check`
- `sudo dpkg --audit`
- `lsblk`
- `lscpu`
- `lshw -short`
- (optional) `lspci -tv`
- `top`
- `free -h`
- `df -h`
- `du -sh /* 2>/dev/null`
- `journalctl -p 3 -xb`
- (Optional information for users)
    - `whoami`
    - `w`
    - `last -a`
    - `sudo -l`

### CentOS modifications

If you want to do this on a CentOS system (or Fedora, RHEL, etc...) then switch out the following commands:


| Category | Debian Command (Current) | CentOS Command (New) | Reason |
| :--- | :--- | :--- | :--- |
| **Package Manager Check** | `apt-get check` | `dnf check` (or `yum check`) | CentOS uses RPM-based `dnf`/`yum` instead of APT. |
| **Package Integrity Audit** | `dpkg --audit` | `rpm -Va --nofiles` | Scans all installed packages for dependency errors or conflicts. |
| **Service Status** | `systemctl status` | `systemctl status` | **No change**. Both systems use `systemd`. |
| **Listening Ports** | `ss -tulnw` | `ss -tulpn` | **Slight variation**. CentOS usually lacks certain defaults, adding `-p` shows the process name. |

### Arch Modifications

If you want to do this on an Arch-based system then switch out the following commands:

| Category | Debian Command | Arch Linux Command | Reason |
| :--- | :--- | :--- | :--- |
| **Package Manager Check** | `apt-get check` | `pacman -Qk` | Checks the integrity of all locally installed packages. |
| **Package Integrity Audit**| `dpkg --audit` | `pacman -D --check` | Scans the local package database for consistency errors or broken dependencies. |
| **Service Status** | `systemctl status` | `systemctl status` | **No change**. Arch uses standard `systemd`. |
| **Listening Ports** | `ss -tulnw` | `ss -tulnw` | **No change**. Standard `iproute2` behavior matches Debian. |

---

## Bash script (for Debian)

1. See the file `sys_audit_debian.md` 
2. Set permissions: `chmod +x sys_audit_debian.md`
3. Run it! `./sys_audit_debian.md`

## Bash script (for CentOS)

1. See the file `sys_audit_centos.md` 
2. Set permissions: `chmod +x sys_audit_centos.md`
3. Run it! `./sys_audit_centos.md`

> Note: Minimal CentOS installations do not always include lshw by default. The script handles this gracefully, but if you notice that section is blank on your CentOS system, you can easily install it by running:
> 
> `sudo dnf install lshw -y`

## Bash script (for Arch)

1. See the file `sys_audit_arch.md` 
2. Set permissions: `chmod +x sys_audit_arch.md`
3. Run it! `./sys_audit_arch.md`

> Note: A fresh Arch installation usually does not include lshw or lspci (part of pciutils) by default. If those sections turn up blank in your report, you can easily install them using:
> 
> `sudo pacman -S lshw pciutils --noconfirm`
