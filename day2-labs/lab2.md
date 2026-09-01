# ⚙️ LAB 2 — SSH Security

In this lab we will:

- Secure SSH networking — port, forwarding, and SFTP restrictions
- Secure SSH user access — root, groups, and authentication
- Verify SSH host keys
- Back up and restore SSH keys
- Configure two-factor authentication with libpam-oath
- Set up brute force protection with fail2ban
- Understand SSH key management with step-ca

> **Note:** This lab is designed for Debian, (for me *deb1* on 10.0.2.51). CentOS notes are included inline.

---

## Estimated Time Summary

| Lab | Task | Time |
|-----|------|------|
| 2a | Securing SSH networking | 8 min |
| 2b | Securing SSH users | 8 min |
| 2c | SSH host key verification | 5 min |
| 2d | Key backup and restoration | 5 min |
| 2e | 2FA with libpam-oath | 8 min |
| 2f | Brute force protection (fail2ban) | 7 min |
| 2g | SSH key management (step-ca) | 5 min |
| Buffer | Q&A | 4 min |
| **Total** | | **~50 min** |

---

## Lab 2a — Securing SSH Networking

**Estimated time: 8 min**

### Check SSH version and status

```bash
ssh -V
systemctl status ssh
```

> **CentOS:**
> ```bash
> systemctl status sshd
> ```

### Validate config before making changes

Always check the config is valid before restarting sshd:

```bash
sudo sshd -t
```

Back up the config before making any changes:

```bash
sudo cp /etc/ssh/sshd_config /etc/ssh/sshd_config.bak
```

### Change the inbound SSH port

Edit `/etc/ssh/sshd_config`:

```bash
sudo vim /etc/ssh/sshd_config
```

Find the line `#Port 22` and change it to:

```
Port 2222
```

---
> **CentOS**: When you change the SSH port on CentOS, SELinux needs to be told the new port is allowed:
> 
> ```bash
> sudo semanage port -a -t ssh_port_t -p tcp 2222
> ```
> 
> Then, verify:
> 
> ```bash
> sudo semanage port -l | grep ssh
> ```
---

> **Note:** Changing the port is security through obscurity — it reduces automated scan noise but is not a substitute for proper authentication hardening.

### Disable TCP port forwarding

SSH tunneling can be used to bypass firewalls. Restrict it:

```bash
AllowTcpForwarding no
```

> **Note:** Only disable this if port forwarding is not needed. Some legitimate use cases such as database tunnels and VPN-over-SSH require it.

### Restrict SFTP

To allow SFTP (only) but restrict users to their home directory, add a dedicated SFTP subsystem block at the end of `sshd_config`:

```
Subsystem sftp internal-sftp

Match Group sftp-users
    ChrootDirectory %h
    ForceCommand internal-sftp
    AllowTcpForwarding no
    X11Forwarding no
```

Create the SFTP group and add a user (but not your primary user!):

```bash
sudo addgroup sftp-users
sudo adduser <other_user> sftp-users
```

>Note: Now that user should only be able to connect via SFTP, not direct SSH connections. They will also be fairly locked down during the SFTP session and will not be able to go above their user's "root" directory. 

### Validate and restart

```bash
sudo sshd -t
sudo systemctl restart ssh
```

> **CentOS:**
> ```bash
> sudo systemctl restart sshd
> ```

### Test the new port from the client

From deb2 (10.0.2.52):

```bash
ssh dave@10.0.2.51 -p 2222
```

---

## Lab 2b — Securing SSH Users

**Estimated time: 8 min**

### Disable root login

Edit `/etc/ssh/sshd_config` and find:

```
#PermitRootLogin prohibit-password
```

Change to:

```
PermitRootLogin no
```

### Disable password authentication

```
PasswordAuthentication no
```

> **Warning:** Ensure key-based authentication is working before disabling passwords. Test from a second terminal first.

### Create an exclusive SSH group

In another terminal: 
```bash
sudo addgroup ssh-allowed
sudo adduser dave ssh-allowed
```

> Note: If the adduser command gives a Perl error, try:
>
> `gpasswd -a dave ssh-allowed`
>
> CentOS users will want `useradd` instead of `adduser`.


In `sshd_config` add the following ABOVE THE SFTP MATCH BLOCK!:

```
AllowGroups ssh-allowed
```

Verify:

```bash
groups dave
```

Test that a user not in the group cannot connect:

```bash
sudo deluser dave ssh-allowed
ssh dave@10.0.2.51 -p 2222
```

> Note: If the deluser command gives a Perl error, try:
>
> `gpasswd -d dave ssh-allowed`
>
> CentOS users will want `userdel` instead of `deluser`. 

Open a new terminal and try SSH'ing in from the client. This should fail. 

Re-add the user:

```bash
sudo adduser dave ssh-allowed
```

Test it again!

### Lower maximum authentication attempts

Find and change:

```
#MaxAuthTries 6
```

to:

```
MaxAuthTries 3
```

### Validate and restart

```bash
sudo sshd -t
sudo systemctl restart ssh
```

> **CentOS:**
> ```bash
> sudo systemctl restart sshd
> ```

---

## Lab 2c — SSH Host Key Verification

**Estimated time: 5 min**

### View the server's host key

On **deb1** (server):

```bash
cat /etc/ssh/ssh_host_ed25519_key.pub
ssh-keygen -lf /etc/ssh/ssh_host_ed25519_key.pub
```

> Note: You can also use the `ssh-keygen -lf <keyname>` command. This shows the SHA-256 fingerprint of the key which can be useful for verifying during a first connection prompt.

### View known_hosts on the client

On **deb2** (client):

```bash
cat ~/.ssh/known_hosts
```

The key stored here should match the server's host key above. (Use `grep` to filter if you have multiple keys on the client.)

---

> **Sidebar**: The first portion of the public key is a hashed version of the remote system's hostname. This is an HMAC-SHA1 one-way function, so we can't reverse engineer it, but we can check against it with (from the client):
>
> `ssh-keygen -F 10.0.2.51`
>
> The hashing protects against casual inspection but not against dtermined attackers that use dictionary or brute force attacks. It is enabled by default in the Debian client at `/etc/ssh_config` with `HashKnownHosts`.

---

### Simulate a changed host key (the scary warning)

> **Warning:** The following commands delete and regenerate the server's SSH host keys. If you are connected to a remote or cloud-based system without console access, this will sever all SSH connectivity and you will need to reconnect via the cloud provider's console or out-of-band management interface. Only run this on a local VM or a system you have console access to.

On **deb1** (server), delete and regenerate the host keys:

```bash
sudo rm /etc/ssh/ssh_host_*
sudo ssh-keygen -A
sudo systemctl restart ssh
```

From **deb2** (client), attempt to connect:

```bash
ssh dave@10.0.2.51 -p 2222
```

You will see the `WARNING: REMOTE HOST IDENTIFICATION HAS CHANGED` message with the `@@@@@` border. This is what a real man-in-the-middle attack or a rebuilt server looks like to SSH. Read the error output carefully!

Remove the old entry and reconnect with the new key:

```bash
ssh-keygen -R 10.0.2.51
ssh dave@10.0.2.51 -p 2222
```

> Note: If this does not work, or the host is not found, use the instructions provided in the terminal using the `ssh-keygen -f` command. 

Accept the new fingerprint when prompted.

> **Note:** In production, never blindly accept a changed host key without verifying out-of-band that the server was intentionally rebuilt or reconfigured. A changed key could indicate a man-in-the-middle attack.

### Strict host key checking

To enforce strict checking and never prompt:

```bash
ssh -o StrictHostKeyChecking=yes dave@10.0.2.51 -p 2222
```

---
> **Sidebar:** In production the realistic workflow is:
> 
> 1. Get the fingerprint from the server during initial provisioning — either via console access, a configuration management tool like Ansible, or a secrets manager
> 2. Pre-populate known_hosts before first connection
> 3. Use StrictHostKeyChecking=yes thereafter so any unexpected key change causes a hard failure rather than a prompt
> 
> 😎 The prompt itself is the weak point — most users type `yes` without verifying, which defeats the purpose entirely.
> 

---

## Lab 2d — Key Backup and Restoration

**Estimated time: 5 min**

### Back up SSH keys

On **deb2** (client), back up the key pair:

```bash
mkdir -p ~/ssh-backup
cp ~/.ssh/id_ed25519 ~/ssh-backup/
cp ~/.ssh/id_ed25519.pub ~/ssh-backup/
chmod 700 ~/ssh-backup
chmod 600 ~/ssh-backup/id_ed25519
```

### Back up the authorized_keys file on the server

On **deb1** (server):

```bash
mkdir -p ~/ssh-backup/
sudo cp /home/dave/.ssh/authorized_keys ~/ssh-backup/authorized_keys.bak
```

> **Note:** Storing the backup on the server itself requires console access to restore in a lockout — consider storing it off-server for better recovery options.

### Simulate key loss and restore

On **deb2**:

```bash
rm ~/.ssh/id_ed25519 ~/.ssh/id_ed25519.pub
ssh-add -D
```

Attemp to connect. It should fail. Oh no! 😥

Now restore the keys.

```bash
cp ~/ssh-backup/id_ed25519 ~/.ssh/
cp ~/ssh-backup/id_ed25519.pub ~/.ssh/
chmod 600 ~/.ssh/id_ed25519
```

Test the connection again. It should work now if you restored properly:

```bash
ssh dave@10.0.2.51 -p 2222
```

Oh YES! 😀

> **Best practice — SSH key backup locations:**
> A local backup is better than nothing, but the most resilient approach is to store SSH keys and `authorized_keys` off the server entirely. Options include:
> - A configuration management system such as Ansible or Puppet
> - A secrets manager such as HashiCorp Vault or Keeper
> - An encrypted, access-controlled backup system
> This ensures access to the backup through an alternative path regardless of SSH availability.

---

## Lab 2e — Two-Factor Authentication Overview

Two-factor authentication (2FA) adds a second layer of verification on top of SSH key authentication. Two common approaches on Linux are **libpam-oath** — an open source TOTP implementation with no dependency on Google services — and **Google Authenticator PAM**, which integrates with the Google Authenticator app. Both work by generating a time-based one-time password (OTP) that expires every 30 seconds, requiring the user to provide it at login in addition to their SSH key.

> See [**Appendix 6**](../z-more-stuff/appendix-6-2FA-SSH.md) for a full hands-on lab covering libpam-oath installation, configuration, and testing.

---

## Lab 2f — Brute Force Protection with fail2ban

fail2ban monitors log files and bans IP addresses that exceed a defined number of failed login attempts within a set time window. It is one of the most effective tools for reducing SSH brute force noise on a public-facing server.

---

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

### Start and enable

```bash
sudo systemctl enable --now fail2ban
sudo systemctl status fail2ban
```

---

### Understanding the configuration structure

fail2ban reads configuration from multiple locations in this order:

1. `/etc/fail2ban/jail.conf` — default config, **overwritten on upgrades, do not edit**
2. `/etc/fail2ban/jail.d/` — drop-in files that extend or override the defaults
3. `/etc/fail2ban/jail.local` — local overrides (alternative to jail.d files)

On Debian, the package ships a pre-configured file at `/etc/fail2ban/jail.d/defaults-debian.conf`. View it:

```bash
cat /etc/fail2ban/jail.d/defaults-debian.conf
```

It contains:

```ini
[DEFAULT]
banaction = nftables
banaction_allports = nftables[type=allports]

[sshd]
backend = systemd
journalmatch = _SYSTEMD_UNIT=ssh.service + _COMM=sshd
enabled = true
```

This file enables the sshd jail using `nftables` for banning and `systemd` for log reading. Do not edit this file — it may be overwritten on upgrades.

---

### Create a custom sshd override

Create a new drop-in file in `jail.d/` that merges with `defaults-debian.conf`:

```bash
sudo vim /etc/fail2ban/jail.d/sshd-custom.conf
```

```ini
[sshd]
port     = 2222
maxretry = 3
bantime  = 1h
findtime = 10m
```

- `port` — must match the SSH port set in Lab 2a
- `maxretry` — number of failures before banning
- `bantime` — how long the ban lasts
- `findtime` — the window in which failures are counted

> **Note:** fail2ban merges all files in `jail.d/` automatically. The settings in `sshd-custom.conf` extend rather than replace `defaults-debian.conf`.

Restart fail2ban to apply:

```bash
sudo systemctl restart fail2ban
sudo systemctl status fail2ban
```

---

### Verify the SSH jail

```bash
sudo fail2ban-client status
sudo fail2ban-client status sshd
```

Confirm the jail is active and the port shows `2222`.

---

### Test fail2ban

From **deb2**, attempt several failed SSH logins deliberately:

```bash
ssh wronguser@10.0.2.51 -p 2222
```

After 3 failures, check the banned IP list on **deb1**:

```bash
sudo fail2ban-client status sshd
```

The IP of deb2 should appear under `Banned IP list`.

### Unban an IP

```bash
sudo fail2ban-client set sshd unbanip 10.0.2.52
```

That's it! 😎

---

### CentOS notes

> **CentOS:** The `defaults-debian.conf` file does not exist on CentOS. Instead, copy `jail.conf` to `jail.local` and configure the `[sshd]` section there:
> ```bash
> sudo cp /etc/fail2ban/jail.conf /etc/fail2ban/jail.local
> sudo vim /etc/fail2ban/jail.local
> ```
> Find the `[sshd]` section and set:
> ```ini
> [sshd]
> enabled  = true
> port     = 2222
> maxretry = 3
> bantime  = 1h
> findtime = 10m
> backend  = systemd
> ```
> CentOS uses `firewalld` for banning by default rather than `nftables`. No additional configuration is needed for this.

### Resources

- `man fail2ban` — comprehensive local reference for all commands and options
- fail2ban official website: https://www.fail2ban.org
- fail2ban GitHub Wiki: https://github.com/fail2ban/fail2ban/wiki
- fail2ban GitHub repository: https://github.com/fail2ban/fail2ban

---

## Lab 2g — SSH Key Management with step-ca

**Estimated time: 5 min**

> **Note:** This section is an instructor demo. Students can follow along visually. The full hands-on lab for step-ca is in Appendix 5a (Debian) and Appendix 5b (CentOS).

### The SSH key sprawl problem

In large environments, SSH keys proliferate without tracking or expiry:

- Admins leave but their keys remain in `authorized_keys` on dozens of servers
- No central record of which keys exist or where
- Revoking access requires manually editing every server

### How step-ca solves it

step-ca acts as an SSH Certificate Authority:

- Every certificate issuance is **logged** by the CA process
- Certificates **expire automatically** — no manual revocation needed for routine access
- Immediate revocation via a KRL (Key Revocation List)

### Start step-ca on the demo server

```bash
step-ca $(step path)/config/ca.json 2>&1 | tee ~/step-ca.log
```

Leave this terminal open — step-ca runs in the foreground and logs all activity including every certificate issuance.

### View provisioners

In a second terminal:

```bash
step ca provisioner list
```

### Track issued certificates

step-ca logs every certificate issuance to the process output. Search the log:

```bash
grep "ssh/sign" ~/step-ca.log
```

The output includes timestamp, principal, serial number, remote address, and validity period — a full audit trail of who received a certificate and when.

### Immediate revocation via KRL (instructor demo)

**Step 1 — Issue a certificate from the client and note the serial number:**

```bash
# On client (ws2)
step ssh inspect ~/.ssh/id_ed25519-cert.pub | grep Serial
```

**Step 2 — Copy the certificate to the server:**

```bash
# On client (ws2)
scp ~/.ssh/id_ed25519-cert.pub user@10.42.17.101:/tmp/
```

**Step 3 — Generate the KRL on the server using the certificate file:**

```bash
# On server (ws1)
sudo ssh-keygen -k -f /etc/ssh/revoked_keys \
  -s $(step path)/certs/ssh_user_ca_key.pub \
  /tmp/id_ed25519-cert.pub
```

**Step 4 — Verify the certificate is revoked:**

```bash
sudo ssh-keygen -Qf /etc/ssh/revoked_keys /tmp/id_ed25519-cert.pub
```

Should return `REVOKED`.

**Step 5 — Tell sshd to enforce the KRL:**

Add to `/etc/ssh/sshd_config`:

```
RevokedKeys /etc/ssh/revoked_keys
```

```bash
sudo systemctl restart ssh
```

**Step 6 — Disable password authentication to test:**

```bash
# Temporarily set in /etc/ssh/sshd_config:
PasswordAuthentication no
```

```bash
sudo systemctl restart ssh
```

**Step 7 — Test from the client:**

```bash
ssh user@10.42.17.101
```

Expected result:


The certificate was rejected by the KRL.

**Step 8 — Restore password authentication:**

```bash
# On server — set back in /etc/ssh/sshd_config:
PasswordAuthentication yes
sudo systemctl restart ssh
```

---

### Other SSH key management tools

| Tool | Type | Notes |
|------|------|-------|
| **Teleport** | Open source | Full SSH access management, certificate-based, audit logging |
| **Keeper** | Commercial | Enterprise secrets and SSH key vault, privileged access management |
| **HashiCorp Vault** | Open source core | SSH secrets engine, dynamic key issuance |

---

## Optional — Banner and MOTD Hardening

### Remove version disclosure from the pre-login banner

Add to `/etc/ssh/sshd_config`:

```
Banner /etc/ssh/banner
```

Create `/etc/ssh/banner`:

```
Authorized access only. All activity is monitored and logged.
```

### Suppress the post-login MOTD

```
PrintMotd no
```

Validate and restart after any optional changes:

```bash
sudo sshd -t
sudo systemctl restart ssh
```

---

## Troubleshooting

**Locked out after config change:**
Boot into recovery mode and restore the backup:
```bash
sudo cp /etc/ssh/sshd_config.bak /etc/ssh/sshd_config
sudo systemctl restart ssh
```

**fail2ban not picking up the new port:**
Confirm `port = 2222` is set in `jail.local` under `[sshd]` and restart fail2ban:
```bash
sudo systemctl restart fail2ban
```

**OTP not accepted:**
Clock skew between client and server will cause TOTP failures. Verify time is synchronized:
```bash
timedatectl status
```

**Connection refused after port change:**
Confirm the firewall allows port 2222:

**Debian:**
```bash
sudo ufw allow 2222/tcp
sudo ufw delete allow 22/tcp
```

> **CentOS:**
> ```bash
> sudo firewall-cmd --permanent --add-port=2222/tcp
> sudo firewall-cmd --permanent --remove-service=ssh
> sudo firewall-cmd --reload
> ```

## SSH Security Documentation

**NIST IR 7966** — "Security of Interactive and Automated Access Management Using Secure Shell (SSH)"

https://nvlpubs.nist.gov/nistpubs/ir/2015/nist.ir.7966.pdf

**Mozilla OpenSSH Guidelines:**

https://infosec.mozilla.org/guidelines/openssh

**CIS Benchmarks:**

https://www.cisecurity.org/benchmark/debian_linux

**OpenSSH man page:**

`man sshd_config`