# ⚙️ LAB 3 — User & Application Security

In this lab we will:

- Review Linux user authentication — passwd, shadow, and PAM
- Enforce password quality with libpam-pwquality
- Configure Mandatory Access Control with AppArmor

> **Note:** This lab is designed for Debian, (for me *deb2* on 10.0.2.52). CentOS notes are included inline.

---

## Estimated Time Summary

| Lab | Task | Time |
|-----|------|------|
| 3a | User authentication + PAM password quality | 20 min |
| 3b | AppArmor + SELinux basics | 20 min |
| Buffer | Q&A | 5 min |
| **Total** | | **~45 min** |

---

## Lab 3a — User Authentication

**Estimated time: 20 min**

### The Linux authentication process

When a user logs in, the following files and components are involved:

| File/Component | Purpose |
|---------------|---------|
| `/etc/passwd` | Stores usernames, UIDs, GIDs, home dirs, and shells. World-readable. |
| `/etc/shadow` | Stores hashed passwords and password policy. Root-only access. |
| `/etc/group` | Stores group memberships. World-readable. |
| PAM | Pluggable Authentication Modules — the framework that enforces authentication rules |

### View /etc/passwd

```bash
cat /etc/passwd
```

Each line contains seven colon-separated fields:

```
username:x:UID:GID:comment:home:shell
```

The `x` in the password field means the password hash is stored in `/etc/shadow`.

### View /etc/shadow

```bash
sudo cat /etc/shadow | head -5
```

Each line contains the username, the hashed password, and password aging fields. The hash format on modern Debian is `$y$` (yescrypt).

### View password aging for a user

```bash
chage -l dave
```

> **Note:** `chage` manages password expiry. Key fields are `Last password change`, `Password expires`, and `Account expires`. Use `sudo chage dave` to modify them.

### View the PAM stack for SSH

PAM modules are configured per-service in `/etc/pam.d/`:

```bash
ls /etc/pam.d/
cat /etc/pam.d/common-auth
```

The `common-auth` file is included by most services and defines the default authentication chain.

---

### Install and configure libpam-pwquality

`libpam-pwquality` enforces password quality rules when a user sets or changes a password.

**Debian:**
```bash
sudo apt install libpam-pwquality -y
```

> **CentOS:**
> ```bash
> sudo dnf install libpwquality -y
> ```
> `pam_pwquality` is already installed by default on CentOS — no separate install needed.

Back up the PAM common-password file before editing:

```bash
sudo cp /etc/pam.d/common-password /etc/pam.d/common-password.bak
```

Edit the pwquality configuration file:

```bash
sudo vim /etc/security/pwquality.conf
```

Set the following parameters:

```ini
# Minimum password length
minlen = 12

# Minimum number of alphabetic characters
minalpha = 2

# Minimum number of numeric characters
mindigit = 1

# Minimum number of character class changes (complexity)
minclass = 3

# Number of characters that must differ from the previous password
difok = 5

# Reject passwords found in a dictionary
dictcheck = 1
```

Add `pam_pwquality.so` to the PAM stack. Edit `/etc/pam.d/common-password`:

```bash
sudo vim /etc/pam.d/common-password
```

Add before the `pam_unix.so` line:

```
password requisite pam_pwquality.so retry=3
```

> **CentOS:** Edit `/etc/pam.d/system-auth` instead and add before the `pam_unix.so` line:
> ```
> password requisite pam_pwquality.so retry=3
> ```

### Increase minimum password length in pam_unix

On the `pam_unix.so` line add `minlen=12`:

```
password [success=1 default=ignore] pam_unix.so obscure yescrypt minlen=12
```

> **Note:** Per NIST SP 800-63B-4 (August 2025), the recommended minimum is 15 characters for password-only authentication and 8 characters when used with MFA.

### Test the configuration

Attempt to change your password to something weak:

```bash
passwd
```

Try a short password and an all-lowercase password — both should be rejected with a descriptive error.

Test a password score:

```bash
pwscore
```

> Install if needed: `sudo apt install libpwquality-tools`

Type a password and press Enter. Returns a score from 0–100. Below 50 is considered weak.

---

## Lab 3b — Mandatory Access Control

**Estimated time: 20 min**

Mandatory Access Control (MAC) enforces security policies at the kernel level — beyond standard Unix permissions. Even root cannot bypass MAC policies.

- **AppArmor** — path-based MAC, default on Debian and Ubuntu
- **SELinux** — label-based MAC, default on CentOS/RHEL

---

### AppArmor (Debian)

#### Check AppArmor status

```bash
sudo apparmor_status
```

This shows loaded profiles and their current mode — `enforce` or `complain`.

- **enforce** — violations are blocked and logged
- **complain** — violations are logged but not blocked (useful for testing)

#### View loaded profiles

```bash
sudo aa-status | grep -E "enforce|complain"
```

#### Install AppArmor utilities

```bash
sudo apt install apparmor-utils -y
```

#### View an existing profile

```bash
sudo cat /etc/apparmor.d/usr.sbin.clamd
```

Profiles define exactly which files, capabilities, and network access a program is allowed.

#### Put a profile into complain mode

Put the `clamd` profile into complain mode:

```bash
sudo aa-complain /usr/sbin/clamd
sudo apparmor_status | grep clamd
```

#### Put the profile back into enforce mode

```bash
sudo aa-enforce /usr/sbin/clamd
sudo apparmor_status | grep clamd
```

#### View AppArmor logs

AppArmor violations are logged to the system journal:

```bash
sudo journalctl -k | grep apparmor | tail -20
```

> **Note:** In complain mode, violations are logged but not blocked — useful for developing new profiles without breaking applications.

---

### SELinux basics (CentOS)

> **CentOS only:** AppArmor is not available on CentOS. SELinux is the MAC system used on CentOS, RHEL, and Fedora.

#### Check SELinux status

```bash
getenforce
sestatus
```

`sestatus` shows the current mode (`Enforcing`, `Permissive`, or `Disabled`) and the policy type (usually `targeted`).

#### View SELinux contexts on files

```bash
ls -Z /etc/ssh/sshd_config
ls -Z /var/log/
```

The `Z` flag shows the SELinux security context — `user:role:type:level`.

#### Temporarily set permissive mode

```bash
sudo setenforce 0
getenforce
```

Set back to enforcing:

```bash
sudo setenforce 1
```

#### View recent SELinux denials

```bash
sudo ausearch -m avc -ts recent
```

#### Fix a file context

If SELinux is blocking access due to wrong file context:

```bash
sudo restorecon -Rv /etc/ssh/
```

> **Note:** Permanent SELinux mode is set in `/etc/selinux/config`. Changing `SELINUX=enforcing` to `SELINUX=permissive` and rebooting disables enforcement permanently — not recommended on production systems.

---

## Troubleshooting

**pwquality not enforcing rules after configuration:**
```bash
sudo pam-auth-update
```
Confirm `pwquality` is listed and enabled.

**AppArmor profile not loading:**
```bash
sudo apparmor_parser -r /etc/apparmor.d/<profile>
sudo apparmor_status
```

**SELinux blocking a service from starting:**
```bash
sudo ausearch -m avc -ts recent | grep <service>
sudo restorecon -Rv /path/to/files
```