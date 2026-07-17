# ⚙️ LAB 1 — Linux Hardening

> *Nothing is 100% secure. The goal is to make it as difficult as possible for an attacker to succeed, and to detect them quickly when they do.*

In this lab we will:

- Update the VM and configure automatic security updates
- Manage services with systemctl
- Secure files and directories
- Describe how to set up intrusion prevention with fail2ban
- Configure anti-malware with ClamAV
- Configure system auditing with auditd

> **Note:** This lab is written for Debian 13 and CentOS Stream 10 or higher. Commands labeled **Debian** apply to Debian and Ubuntu. Commands labeled **CentOS** apply to CentOS Stream, RHEL, Fedora, and RHEL clones. CentOS Stream differences are noted inline throughout.

---

## Estimated Time Summary

| Lab | Task | Time |
|-----|------|------|
| 1a | Updating the VM | 6 min |
| 1b | Automatic security updates | 6 min |
| 1c | systemctl and services | 7 min |
| 1d | Securing files | 7 min |
| 1e | Intrusion prevention (fail2ban) | n/a |
| 1f | Anti-malware (ClamAV) | 7 min |
| 1g | Auditing (auditd) | 7 min |
| Buffer | Q&A, etc... | 15 min |
| **Total** | | **~55 min** |

---

## Lab 1a — Updating the VM

**Estimated time: 4 min**

First, check for available updates without installing them:

**Debian:**
```bash
sudo apt update
```

> **CentOS:**
> ```bash
> sudo dnf check-update
> ```

Review the list of available updates. Note the number of security updates available.

> **Optional — perform the full upgrade** (can be done after the session):
>
> **Debian:**
> ```bash
> sudo apt upgrade -y
> sudo apt autoremove -y
> ```
>
> **CentOS:**
> ```bash
> sudo dnf upgrade -y
> sudo dnf autoremove -y
> ```

Verify the running kernel:

```bash
uname -r
```

> **Note:** If a kernel update is installed, a reboot is required to activate it.

---

## Lab 1b — Installing Automatic Security Updates

**Estimated time: 6 min**

First, check what security updates are available:

**Debian:**
```bash
sudo apt-get -s dist-upgrade | grep -i security
```

> **CentOS:**
> ```bash
> dnf check-update --security
> ```
> Only security updates can be installed with:
> ```bash
> sudo dnf update --security
> ```

### Install unattended-upgrades

**Debian:**
```bash
sudo apt install unattended-upgrades apt-listchanges -y
sudo dpkg-reconfigure -plow unattended-upgrades
```

Select **Yes** when prompted.

View the configuration:

```bash
sudo cat /etc/apt/apt.conf.d/50unattended-upgrades
```

The key setting that controls which updates are applied automatically:

```
Unattended-Upgrade::Origins-Pattern {
    "origin=Debian,codename=${distro_codename},label=Debian";
    "origin=Debian,codename=${distro_codename},label=Debian-Security";
    "origin=Debian,codename=${distro_codename}-security,label=Debian-Security";
};
```

Security updates are enabled by default. The commented-out lines for `-updates` and `-proposed-updates` can be uncommented to include non-security updates as well.

Test without making changes:

```bash
sudo unattended-upgrades --dry-run --debug
```

> **CentOS:**
> ```bash
> sudo dnf install dnf-automatic -y
> sudo vim /etc/dnf/automatic.conf
> ```
> Set:
> ```ini
> upgrade_type = security
> apply_updates = yes
> ```
> Enable the timer:
> ```bash
> sudo systemctl enable --now dnf-automatic.timer
> sudo systemctl status dnf-automatic.timer
> ```

---

## Lab 1c — systemctl and Services

**Estimated time: 7 min**

### View running services

```bash
systemctl list-units --type=service --state=running
```

### List enabled services

```bash
systemctl list-unit-files --type=service --state=enabled
```

### Disable an unnecessary service

**Debian** — disable `avahi-daemon` if not needed:
```bash
sudo systemctl stop avahi-daemon
sudo systemctl disable avahi-daemon
```

> **Note:** avahi-daemon has a companion socket unit that will automatically restart the service if something connects to it. Stop and disable the socket as well:
> ```bash
> sudo systemctl stop avahi-daemon.socket
> sudo systemctl disable avahi-daemon.socket
> ```

**Option 2 — Mask both to prevent them from ever starting:**
```bash
sudo systemctl mask avahi-daemon.service avahi-daemon.socket
```

Unmask when needed:
```bash
sudo systemctl unmask avahi-daemon.service avahi-daemon.socket
```

> **CentOS** — `avahi-daemon` may not be installed. Use `cups` or `rpcbind` as examples if present:
> ```bash
> sudo systemctl stop rpcbind
> sudo systemctl disable rpcbind
> ```

### Check for failed services

```bash
systemctl status
systemctl --failed
```

---

## Lab 1d — Securing Files

**Estimated time: 7 min**

### Check world-writable files

```bash
sudo find / -xdev -type f -perm -o+w 2>/dev/null
```

> **Note:** A minimal server install with no GUI or extra software will return little to no results. A desktop or developer system with applications like NoMachine, VSCode, or similar will return a longer list — those entries are expected given what is installed. Always question anything unexpected, especially on a production server.

### Check for SUID/SGID binaries

```bash
sudo find / -xdev -type f \( -perm -4000 -o -perm -2000 \) 2>/dev/null
```

> **Note:** A minimal Debian server install returns very few results here. A desktop system will return a longer list due to GUI tools and third-party applications. The key is knowing your baseline — audit this list after installing any new software.

### Set correct permissions on sensitive files

```bash
sudo chmod 600 /etc/shadow
sudo chmod 644 /etc/passwd
sudo chmod 644 /etc/group
ls -la /etc/shadow /etc/passwd /etc/group
```

> **Note:** `/etc/shadow` is the critical one here — it contains hashed passwords. The default is `640` which allows the `shadow` group to read it. Changing to `600` restricts access to root only.
>
> **CentOS:** `/etc/shadow` is set to `000` by default — no permissions for any user. Root can still access it because root bypasses permission checks entirely, making it more restrictive than Debian's default. No change is needed on CentOS.

### Check for files with no owner

```bash
sudo find / -xdev \( -nouser -o -nogroup \) 2>/dev/null
```

### Verify sticky bit on /tmp

```bash
ls -ld /tmp
```

The `t` at the end of the permissions confirms the sticky bit is set. Set it if missing:

```bash
sudo chmod +t /tmp
```

> `/tmp` is world-writable, meaning any user can create files there. Without the sticky bit, any user could also delete or rename files owned by other users — including files belonging to running processes. The sticky bit restricts deletion and renaming to the file's owner only, preventing one user from interfering with another's temporary files.

> **CentOS:** SELinux provides additional file access controls beyond standard permissions. Verify SELinux is enforcing:
> ```bash
> getenforce
> ```
> If not enforcing:
> ```bash
> sudo setenforce 1
> ```

---

## Lab 1e — Setting Up Intrusion Prevention with fail2ban *(Optional)*

**Estimated time: 8 min**

> **Note:** fail2ban will be configured in detail during Lab 2 (SSH Security). This section is optional — skip it if time is short and return to it during Lab 2.

fail2ban monitors log files and bans IP addresses that show repeated failed login attempts. It sits in the category of **intrusion prevention** — it detects malicious patterns and takes automated action.

> **Other intrusion detection and prevention tools worth knowing:**
> - **Snort** — open source network intrusion detection system (NIDS) that analyzes network traffic in real time
> - **Suricata** — modern, multi-threaded alternative to Snort with built-in IDS, IPS, and network security monitoring capabilities

### Install fail2ban

**Debian:**
```bash
sudo apt install fail2ban -y
```

> **CentOS:**
> ```bash
> sudo dnf install epel-release -y
> sudo dnf install fail2ban -y
> ```

### Configure fail2ban

```bash
sudo cp /etc/fail2ban/jail.conf /etc/fail2ban/jail.local
sudo vim /etc/fail2ban/jail.local
```

Find and verify the `[sshd]` section:

```ini
[sshd]
enabled  = true
port     = ssh
maxretry = 3
bantime  = 1h
findtime = 10m
```

> **CentOS:** The SSH service name in fail2ban may need to be set to `sshd` explicitly and the log backend changed:
> ```ini
> [sshd]
> enabled  = true
> port     = ssh
> maxretry = 3
> bantime  = 1h
> findtime = 10m
> backend  = systemd
> ```

### Start and enable fail2ban

```bash
sudo systemctl enable --now fail2ban
sudo systemctl status fail2ban
```

### Verify SSH jail is active

```bash
sudo fail2ban-client status
sudo fail2ban-client status sshd
```

### Unban an IP if needed

```bash
sudo fail2ban-client set sshd unbanip <ip-address>
```

---

## Lab 1f — Configuring Anti-Malware with ClamAV

**Estimated time: 7 min**

### Install ClamAV

**Debian:**
```bash
sudo apt install clamav clamav-daemon -y
```

> **CentOS:**
> ```bash
> sudo dnf install epel-release -y
> sudo dnf install clamav clamd clamav-update -y
> ```

### Update virus definitions

ClamAV starts the `clamav-freshclam` service automatically on install and updates definitions in the background. Verify it is running:

```bash
systemctl status clamav-freshclam
```

Check the current database version:

```bash
sudo freshclam --version
```

> **CentOS:**
> ```bash
> sudo freshclam
> sudo systemctl enable --now clamav-freshclam
> ```

### Run a manual scan

```bash
clamscan -r --bell -i ~/
```

- `-r` — recursive
- `--bell` — alert on detection
- `-i` — show infected files only

> **Note:** A full system scan (`sudo clamscan -r /`) takes a long time. Show the command then press `Ctrl+C`.

### Schedule automatic scans

```bash
sudo crontab -e
```

Add:

```
0 2 * * * clamscan -r --bell -i /home >> /var/log/clamav/daily-scan.log 2>&1
```

This runs a recursive scan of `/home` at 2am daily and appends results to the log file.

> **Note:** cron is ideal for servers that run continuously. For client systems that may be powered off at 2am, consider `anacron` instead — it runs missed jobs at the next system startup. Debian installs `anacron` by default alongside `cron`.

### Check ClamAV status

Enable and start the ClamAV scanning daemon:

**Debian:**
```bash
sudo systemctl enable --now clamav-daemon
```

> **CentOS:**
> ```bash
> sudo systemctl enable --now clamd@scan
> ```

Verify both services are running:

```bash
sudo systemctl status clamav-daemon
sudo systemctl status clamav-freshclam
```

> **Note:** `clamav-daemon` will not start until virus definitions are downloaded. If it shows `condition unmet`, the definitions may still be downloading. Once definitions appear in `/var/lib/clamav/`, force a restart:
> ```bash
> sudo systemctl restart clamav-daemon
> ```

> **Note:** `clamav-freshclam` may show as `disabled` even though it is running — this is because the system preset activated it at install time rather than a standard `systemctl enable`. Ensure it starts on future reboots:
> ```bash
> sudo systemctl enable clamav-freshclam
> ```
> The warning `Clamd was NOT notified` in the freshclam log is expected if `clamav-daemon` was not running when definitions were downloaded. It will resolve on the next freshclam update cycle.

> **CentOS:**
> ```bash
> sudo systemctl status clamd@scan
> sudo systemctl status clamav-freshclam
> ```

---

## Lab 1g — Configuring Auditing with auditd

**Estimated time: 7 min**

auditd records system calls and file access events, providing a detailed audit trail for security and compliance.

### Install and start auditd

**Debian:**
```bash
sudo apt install auditd -y
sudo systemctl enable --now auditd
```

> **CentOS:** auditd is installed by default. Just enable it:
> ```bash
> sudo systemctl enable --now auditd
> ```

### View current rules

```bash
sudo auditctl -l
```

### Add audit rules

```bash
sudo auditctl -a always,exit -F path=/etc/passwd -F perm=wa -k passwd-changes
sudo auditctl -a always,exit -F path=/etc/shadow -F perm=wa -k shadow-changes
sudo auditctl -a always,exit -F path=/etc/sudoers -F perm=wa -k sudoers-changes
```

- `-a always,exit` — log on every syscall exit
- `-F path` — the file to watch
- `-F perm=wa` — log write and attribute changes
- `-k` — tag events with this key

### Trigger and view an event

```bash
sudo touch /etc/passwd
sudo ausearch -k passwd-changes
```

### Generate an audit report

```bash
sudo aureport --summary
```

### Make rules persistent

```bash
sudo auditctl -l | sudo tee /etc/audit/rules.d/hardening.rules
sudo systemctl restart auditd
sudo auditctl -l
```

### Remove audit rules

To remove all currently loaded audit rules at once:

```bash
sudo auditctl -D
```

To remove individual rules, use `-d` with the same syntax used to add them:

```bash
sudo auditctl -d always,exit -F path=/etc/passwd -F perm=wa -k passwd-changes
sudo auditctl -d always,exit -F path=/etc/shadow -F perm=wa -k shadow-changes
sudo auditctl -d always,exit -F path=/etc/sudoers -F perm=wa -k sudoers-changes
```

Verify rules are removed:

```bash
sudo auditctl -l
```

---

## 🎉 Congratulations — you have completed Lab 1: Linux Hardening!

---

## Troubleshooting

**unattended-upgrades not running:**
```bash
sudo systemctl status unattended-upgrades
sudo journalctl -u unattended-upgrades -n 20
```

**fail2ban not banning:**
```bash
sudo fail2ban-client status sshd
sudo journalctl -u fail2ban -n 20
```

**ClamAV definitions out of date:**
```bash
sudo systemctl stop clamav-freshclam
sudo freshclam
sudo systemctl start clamav-freshclam
```

**auditd rules not persisting after reboot:**
```bash
sudo cat /etc/audit/rules.d/hardening.rules
sudo systemctl restart auditd
sudo auditctl -l
```

> **CentOS — SELinux blocking auditd:**
> ```bash
> sudo ausearch -m avc -ts recent | grep auditd
> sudo restorecon -Rv /etc/audit/
> ```

---

## Reading auditd Output — Key Components

When you run `sudo ausearch -k passwd-changes` the output contains several important fields. Here is an example and what each component means:

```
time->Fri Jul 17 10:36:17 2026
type=PROCTITLE msg=audit(1784298977.892:382): proctitle=746F756368002F6574632F706173737764
type=PATH msg=audit(1784298977.892:382): item=0 name="/etc/passwd" inode=132629 dev=fe:01 mode=0100644 ouid=0 ogid=0 rdev=00:00 nametype=NORMAL
type=CWD msg=audit(1784298977.892:382): cwd="/home/dave"
type=SYSCALL msg=audit(1784298977.892:382): arch=c000003e syscall=257 success=yes exit=3 ppid=38263 pid=38264 auid=1000 uid=0 gid=0 euid=0 comm="touch" exe="/usr/bin/touch" key="passwd-changes"
```

| Field | Value | Meaning |
|-------|-------|---------|
| `time` | Fri Jul 17 10:36:17 2026 | When the event occurred |
| `name` | `/etc/passwd` | The file that was accessed |
| `exe` | `/usr/bin/touch` | The program that made the change |
| `comm` | `touch` | The command name |
| `uid` | `0` | The user ID the command ran as (root) |
| `auid` | `1000` | The audit UID — the original logged-in user who invoked sudo |
| `success` | `yes` | The operation succeeded |
| `key` | `passwd-changes` | The tag set with `-k` confirming our rule was triggered |

The most forensically useful combination is `auid` (who), `exe` (what program), `name` (what file), and `time` (when).

## More on File Security

Files such as passwd, sudo, su, mount, newgrp, gpasswd and similar are legitimate system binaries that require SUID to function. They show up on many systems that have a GUI or have the sudo program running. Removing the SUID bit would break them. Here's the command we issued in Lab 1d.

```
sudo find / -xdev -type f \( -perm -4000 -o -perm -2000 \) 2>/dev/null
```

The goal with the previous command is not to remove all SUID/SGID binaries — it is to:

1. **Know your baseline** — document what is on the system now
2. **Identify unexpected additions** — if a new SUID binary appears that was not there before, that is a red flag
3. **Question third-party software** — the NoMachine scripts, Chrome sandboxes, and Cursor entries are worth reviewing to ensure they are expected and from trusted sources

A practical hardening step is to save the current list to a file and compare it periodically:
```
sudo find / -xdev -type f \( -perm -4000 -o -perm -2000 \) 2>/dev/null > ~/suid-baseline.txt
```

Then on future audits:
```
sudo find / -xdev -type f \( -perm -4000 -o -perm -2000 \) 2>/dev/null > ~/suid-current.txt
diff ~/suid-baseline.txt ~/suid-current.txt
```

Any new entries in the diff warrant investigation. 

🪱 ***Again... It is the LEGEND!*** 🪱