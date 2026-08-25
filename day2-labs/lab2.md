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

> **Note:** Changing the port is security through obscurity — it reduces automated scan noise but is not a substitute for proper authentication hardening.

### Disable TCP port forwarding

SSH tunneling can be used to bypass firewalls. Restrict it:

```bash
AllowTcpForwarding no
```

> **Note:** Only disable this if port forwarding is not needed. Some legitimate use cases such as database tunnels and VPN-over-SSH require it.

### Restrict SFTP

To allow SFTP but restrict users to their home directory, add a dedicated SFTP subsystem block at the end of `sshd_config`:

```
Subsystem sftp internal-sftp

Match Group sftp-users
    ChrootDirectory %h
    ForceCommand internal-sftp
    AllowTcpForwarding no
    X11Forwarding no
```

Create the SFTP group and add a user:

```bash
sudo addgroup sftp-users
sudo adduser dave sftp-users
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

```bash
sudo addgroup ssh-allowed
sudo adduser dave ssh-allowed
```

Add to `sshd_config`:

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

This should fail. Re-add the user:

```bash
sudo adduser dave ssh-allowed
```

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

### View the server's host key fingerprint

On **deb1** (server):

```bash
ssh-keygen -lf /etc/ssh/ssh_host_ed25519_key.pub
```

### View known_hosts on the client

On **deb2** (client):

```bash
cat ~/.ssh/known_hosts
```

The fingerprint stored here should match the server's host key above.

### Simulate a host key change

On **deb1**, view the current host keys:

```bash
ls -la /etc/ssh/ssh_host_*
```

On **deb2**, attempt to connect after manually removing the known_hosts entry:

```bash
ssh-keygen -R 10.0.2.51
ssh dave@10.0.2.51 -p 2222
```

SSH will warn that the host is unknown and prompt to verify the fingerprint. This is the expected behavior when a host key changes — in production, always verify out-of-band before accepting.

### Strict host key checking

To enforce strict checking and never prompt:

```bash
ssh -o StrictHostKeyChecking=yes dave@10.0.2.51 -p 2222
```

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
sudo cp /home/dave/.ssh/authorized_keys ~/ssh-backup/authorized_keys.bak
```

### Simulate key loss and restore

On **deb2**:

```bash
rm ~/.ssh/id_ed25519 ~/.ssh/id_ed25519.pub
cp ~/ssh-backup/id_ed25519 ~/.ssh/
cp ~/ssh-backup/id_ed25519.pub ~/.ssh/
chmod 600 ~/.ssh/id_ed25519
```

Test the connection:

```bash
ssh dave@10.0.2.51 -p 2222
```

> **Note:** In production, SSH keys should be backed up to an encrypted location — an external drive, a secrets manager, or an encrypted archive. Never store private keys in plaintext on a shared system.

---

## Lab 2e — 2FA with libpam-oath

**Estimated time: 8 min**

libpam-oath adds TOTP (Time-based One-Time Password) authentication to SSH without depending on Google software.

### Install

**Debian:**
```bash
sudo apt install libpam-oath oathtool -y
```

> **CentOS:**
> ```bash
> sudo dnf install epel-release -y
> sudo dnf install oathtool pam_oath -y
> ```

### Generate a secret key

```bash
HEX_SECRET=$(head -c 1024 /dev/urandom | openssl sha1 | awk '{print $2}')
echo $HEX_SECRET
```

### Add the user to the oath users file

```bash
sudo bash -c "echo 'HOTP/T30/6 dave - $HEX_SECRET' >> /etc/users.oath"
sudo chmod 600 /etc/users.oath
sudo chown root:root /etc/users.oath
```

### Generate a test OTP to verify

```bash
oathtool --totp -d 6 $HEX_SECRET
```

This generates the current 6-digit OTP. Note it — it changes every 30 seconds.

### Configure PAM

Edit `/etc/pam.d/sshd`:

```bash
sudo vim /etc/pam.d/sshd
```

Add at the top (before `@include common-auth`):

```
auth required pam_oath.so usersfile=/etc/users.oath window=30 digits=6
```

### Configure sshd_config

Add or uncomment:

```
ChallengeResponseAuthentication yes
UsePAM yes
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

### Test

From deb2:

```bash
ssh dave@10.0.2.51 -p 2222
```

You should be prompted for the OTP. Generate it:

```bash
oathtool --totp -d 6 $HEX_SECRET
```

> **Note:** For production use, pair this with an authenticator app such as FreeOTP or Aegis — both are open source and do not require Google services. Scan a QR code generated from the hex secret to add it to the app.

---

## Lab 2f — Brute Force Protection with fail2ban

**Estimated time: 7 min**

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

### Configure for SSH

```bash
sudo cp /etc/fail2ban/jail.conf /etc/fail2ban/jail.local
sudo vim /etc/fail2ban/jail.local
```

Find the `[sshd]` section and set:

```ini
[sshd]
enabled  = true
port     = 2222
maxretry = 3
bantime  = 1h
findtime = 10m
```

> **Note:** We changed the SSH port to 2222 in Lab 2a — update the `port` value here to match.

> **CentOS:** Add the backend parameter:
> ```ini
> backend = systemd
> ```

### Start and enable

```bash
sudo systemctl enable --now fail2ban
sudo systemctl status fail2ban
```

### Verify SSH jail

```bash
sudo fail2ban-client status
sudo fail2ban-client status sshd
```

### Test

From deb2, attempt several failed SSH logins deliberately:

```bash
ssh wronguser@10.0.2.51 -p 2222
```

After 3 failures, check the banned IP:

```bash
sudo fail2ban-client status sshd
```

### Unban

```bash
sudo fail2ban-client set sshd unbanip 10.0.2.52
```

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

- Every certificate issuance is **logged** with the principal, timestamp, and serial number
- Certificates **expire automatically** — no manual revocation needed for routine access
- Immediate revocation via a KRL (Key Revocation List)

### Tracking issued certificates (instructor demo)

On the step-ca server, view the certificate database:

```bash
step ca admin list
```

View the audit log of issued certificates:

```bash
cat $(step path)/db/issuedCerts
```

### Immediate revocation via KRL (instructor demo)

Generate a KRL file that revokes a specific certificate by serial number:

```bash
ssh-keygen -k -f /etc/ssh/revoked_keys -s /etc/ssh/ssh_ca.pub \
  -z <serial-number> /dev/null
```

Tell sshd to enforce it — add to `/etc/ssh/sshd_config`:

```
RevokedKeys /etc/ssh/revoked_keys
```

```bash
sudo systemctl restart ssh
```

Any certificate with that serial number will now be rejected immediately — before its expiry.

### Other SSH key management tools

| Tool | Type | Notes |
|------|------|-------|
| **Teleport** | Open source | Full SSH access management, certificate-based, audit logging |
| **Keeper** | Commercial | Enterprise secrets and SSH key vault, privileged access management |
| **HashiCorp Vault** | Open source core | SSH secrets engine, dynamic key issuance |

---

## Optional — SSH Timeouts

Add to `/etc/ssh/sshd_config`:

```
ClientAliveInterval 300
ClientAliveCountMax 2
```

This disconnects idle sessions after 10 minutes (300 seconds × 2 checks).

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