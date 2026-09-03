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

> **Note on epoch:** Dates in `/etc/shadow` are stored as the number of days since January 1, 1970 (the Unix epoch) — not as human-readable dates. For example, the value `19920` means 19,920 days since January 1, 1970. The `chage -l` command converts these epoch day values into readable dates automatically, which is why it is the preferred way to view password aging information rather than reading `/etc/shadow` directly.

### View the PAM stack

PAM modules are configured per-service in `/etc/pam.d/`:

```bash
ls /etc/pam.d/
cat /etc/pam.d/common-auth
cat /etc/pam.d/common-password
```

The `common-auth` file is included by most services and defines the default authentication chain. The `common-password` file manages password changes — note that `pam_pwquality` is not yet present here. We will install it next and then verify it has been added automatically.

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

Back up the pwquality configuration file before editing:

```bash
sudo cp /etc/security/pwquality.conf /etc/security/pwquality.conf.bak
```

Edit the pwquality configuration file:

```bash
sudo vim /etc/security/pwquality.conf
```

Set the following parameters:

```ini
# Minimum password length
minlen = 15

# Minimum number of digits required (-1 = at least 1)
dcredit = -1

# Minimum number of uppercase characters required (-1 = at least 1)
ucredit = -1

# Minimum number of lowercase characters required (-1 = at least 1)
lcredit = -1

# Minimum number of special characters required (-1 = at least 1)
ocredit = -1

# Minimum number of character classes that must be present (digits, upper, lower, special)
minclass = 4

# Number of characters that must differ from the previous password
difok = 3

# Reject passwords found in a dictionary
dictcheck = 1
```

> **Note:** The credit parameters (`dcredit`, `ucredit`, `lcredit`, `ocredit`) use negative values to set minimums — `-1` means at least 1 of that character type is required. Positive values work as bonus credits toward `minlen` which is legacy behavior and rarely used today.
>
> Newer alternatives that some find more intuitive: `mindigit = 1` instead of `dcredit = -1`, and `minalpha = 2` instead of separate `ucredit`/`lcredit` values. Both approaches work on Debian 13.

### Verify pam_pwquality is active in the PAM stack

Installing `libpam-pwquality` automatically adds `pam_pwquality.so` to the PAM stack via `pam-auth-update`. Verify it is present:

**Debian:**
```bash
grep pam_pwquality /etc/pam.d/common-password
```

> **CentOS:**
> ```bash
> grep pam_pwquality /etc/pam.d/system-auth
> ```

The `pam_pwquality.so` line should now be present — confirming it was added automatically by the install.

> **Note:** No service restart is required after modifying `/etc/security/pwquality.conf`. PAM modules are `.so` shared libraries loaded at authentication time — changes take effect immediately on the next login or password change attempt.

> **Historical note:** In older distributions, `minlen` and character requirements were set differently depending on the distro. On Debian, settings were added directly to the `pam_unix.so` line in `/etc/pam.d/common-password`. On CentOS/RHEL, `/etc/pam.d/password-auth` was modified instead. Both approaches required distro-specific knowledge and were error-prone. Today, `pam_pwquality` unifies this across all major distributions — `/etc/security/pwquality.conf` is the single source of truth regardless of distro, and `pam_pwquality.so` is added to the PAM stack automatically on install.

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

> **Note — pwscore consistency:** `pwscore` results vary between distributions and even between systems depending on which dictionaries are installed. The same password may score 100 on CentOS and 48 on Debian because each system ships with different dictionary databases and scoring algorithms. A lower score on Debian may indicate the dictionary recognized real words or names in the password even with substitutions. Treat the score as a guideline rather than an absolute measure.

> **Note — Password history:** `/etc/security/pwhistory.conf` controls how many previous passwords are remembered and rejected on reuse. The default on Debian 13 is 10 — meaning a user cannot reuse any of their last 10 passwords. This is managed by `pam_pwhistory.so` and requires no additional configuration to be active.

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

> **Note:** `apparmor_status` can be abbreviated to `aa-status` — both produce identical output.

#### View loaded profiles

```bash
sudo aa-status | grep -E "enforce|complain"
```

AppArmor is running on Debian automatically (you can view it with `systemctl status apparmor`) but to make modifications you will need AppArmor utilities.

#### Install AppArmor utilities

```bash
sudo apt install apparmor-utils -y
```

#### View an existing profile

```bash
sudo cat /etc/apparmor.d/usr.sbin.clamd
```

Profiles define exactly which files, capabilities, and network access a program is allowed.

To check the current mode of the `clamd` profile specifically:

```bash
sudo aa-status | grep -E "clamd|mode"
```

Or read directly from the kernel security filesystem:

```bash
sudo cat /sys/kernel/security/apparmor/profiles | grep clamd
```

This shows the profile name followed by its mode in parentheses — for example `usr.sbin.clamd (enforce)`.

> **Note:** There is no single dedicated AppArmor command to check the mode of one specific profile — these are the most practical options available.

#### Put a profile into complain mode

Put the `clamd` profile into complain mode:

```bash
sudo aa-complain /usr/sbin/clamd
sudo cat /sys/kernel/security/apparmor/profiles | grep clamd
```

#### Make a simple profile modification

With the profile in complain mode, add a deny rule to demonstrate how profiles restrict access. Edit the profile:

```bash
sudo vim /etc/apparmor.d/usr.sbin.clamd
```

Add the following line just before the closing `}` brace:

```
  deny /etc/hostname r,
```

Reload the profile:

```bash
sudo apparmor_parser -r /etc/apparmor.d/usr.sbin.clamd
```

> **Note:** In complain mode, violations are logged but not blocked — useful for developing new profiles without breaking applications.

Switch to enforce mode and verify:

```bash
sudo aa-enforce /usr/sbin/clamd
sudo cat /sys/kernel/security/apparmor/profiles | grep clamd
```

#### View AppArmor logs

In a production environment, when a confined process attempts to access a denied resource you will see `apparmor="DENIED"` entries in the journal. Profile load events appear at boot:

```bash
sudo journalctl -k | grep apparmor | tail -10
```

Look for entries containing `apparmor="DENIED"` — these indicate a policy violation was caught. `apparmor="STATUS"` entries are informational and show profiles being loaded.

> **Note:** For a full hands-on AppArmor lab including custom profile creation and violation testing using Apache as an example, see the [Linux Security video course](https://learning.oreilly.com/videos/linux-security/9780135338001/9780135338001-LSB1_02_09_03/).

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
ls -Z /etc/shadow
```

> **Note on SELinux types:** The `type` field is the most important part of the SELinux context — it defines what processes are allowed to access the file:
> - `etc_t` — general configuration files, readable by many system processes
> - `var_log_t` — log files, writable only by logging-related processes
> - `shadow_t` — password hash file, accessible only by privileged authentication processes such as PAM — even processes running as root cannot access it without the correct type

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

> **Note:** `<no matches>` is a good result — it means SELinux is not blocking anything on your system. On a well-configured system this is the expected output. A denial would look like this:
>
> ```
> type=AVC msg=audit(1234567890.123:456): avc: denied { read } for pid=1234
> comm="httpd" name="secret.conf" dev="sda1" ino=12345
> scontext=system_u:system_r:httpd_t:s0
> tcontext=system_u:object_r:shadow_t:s0 tclass=file permissive=0
> ```
>
> Key fields: `denied` — what happened, `comm` — the process that was blocked, `read` — the action attempted, `scontext` — the source (process) context, `tcontext` — the target (file) context.

#### Fix a file context

If SELinux is blocking access due to wrong file context:

```bash
sudo restorecon -Rv /etc/ssh/
```

This resets the SELinux security context of files in `/etc/ssh/` back to the default context defined in the SELinux policy — useful when files have been copied or moved and inherited the wrong context.

> **Note:** Permanent SELinux mode is set in `/etc/selinux/config`. Changing `SELINUX=enforcing` to `SELINUX=permissive` and rebooting disables enforcement permanently — not recommended on production systems.

> **Note:** For more information on SELinux, see the video course: [*Mastering Security-Enhanced Linux*](https://learning.oreilly.com/course/mastering-securityenhanced-linux/9780138282691/).

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

---

## PAM Components

There are a lot of different pluggable authentication modules (PAM). The following table lists some of the common PAM components used by Debian and CentOS.

| Component | Type | Era | Distro | Purpose |
|-----------|------|-----|--------|---------|
| `common-auth` | PAM config | Classic | Debian/Ubuntu | Handles user identity verification at login |
| `common-account` | PAM config | Classic | Debian/Ubuntu | Validates account status — expiry, locks, time restrictions |
| `common-password` | PAM config | Classic | Debian/Ubuntu | Enforces rules and updates the password store on password change |
| `common-session` | PAM config | Classic | Debian/Ubuntu | Sets up and tears down the user session after login |
| `system-auth` | PAM config | Mid-era | CentOS/RHEL | Combined auth, account, password, and session for system logins |
| `password-auth` | PAM config | Mid-era | CentOS/RHEL | Same as system-auth but used for remote/network-based logins |
| `pam_pwquality.so` | PAM module | Modern | All distros | Enforces password complexity rules via `/etc/security/pwquality.conf` |
| `pam_pwhistory.so` | PAM module | Modern | All distros | Tracks and rejects reuse of previous passwords via `/etc/security/pwhistory.conf` |
| `systemd-homed` | systemd service | Newest | Modern distros | Manages user home directories and credentials independently of PAM |

---

## Resources

- `man pam_pwquality` — full reference for pwquality configuration options
- `man apparmor` — AppArmor overview and usage
- **NIST SP 800-63B-4** — Digital Identity Guidelines: Authentication and Authenticator Management (finalized July 2025): https://doi.org/10.6028/NIST.SP.800-63B-4
- **Debian Securing Manual** — PAM and password configuration: https://www.debian.org/doc/manuals/securing-debian-manual/ch04s11.en.html
- **AppArmor Wiki**: https://gitlab.com/apparmor/apparmor/-/wikis/home
- **SELinux Project**: https://selinuxproject.org