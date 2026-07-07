# Appendix 5b — SSH Certificates with Smallstep step-ca (CentOS Stream 10)

## Overview

This lab sets up a Smallstep `step-ca` Certificate Authority on a server VM and uses it to issue SSH user certificates to a client VM. Smallstep step-ca is free and open source software.

Reference: https://smallstep.com/docs/step-ca/getting-started/

| Role   | Example IP     |
|--------|----------------|
| Server | 10.42.17.131   |
| Client | 10.42.17.132   |

> **Note:** IP addresses above are examples. Substitute your actual IP addresses throughout the lab.

> **Note:** This lab is written for CentOS Stream 10. If using Debian 13, see Appendix 5a.

> **Note:** Port 443 requires root. This lab uses port 8443.

---

## Part 1 — Server: Install step-cli and step-ca

```bash
sudo dnf install -y curl

cat << EOF | sudo tee /etc/yum.repos.d/smallstep.repo
[smallstep]
name=Smallstep
baseurl=https://packages.smallstep.com/stable/fedora/
enabled=1
repo_gpgcheck=0
gpgcheck=1
gpgkey=https://packages.smallstep.com/keys/smallstep-0x889B19391F774443.gpg
EOF

sudo dnf makecache
sudo dnf install -y step-cli step-ca
```

Verify:
```bash
step version
step-ca version
```

---

## Part 2 — Server: Initialize the CA

```bash
step ca init --ssh
```

Answer the prompts:

| Prompt | Value |
|--------|-------|
| Deployment type | **Standalone** |
| CA name | Your choice (e.g. `lab-ca`) |
| DNS names or IP | Your server IP address |
| Address | `:8443` |
| First provisioner | Your email or any identifier |
| Password | Choose a strong password |

> **Note:** Note the CA fingerprint shown at the end — you will need it on the client in Part 6.

---

## Part 3 — Server: Start step-ca

```bash
step-ca $(step path)/config/ca.json
```

Enter the password when prompted. Leave this terminal open — step-ca runs in the foreground.

Verify it is listening in a second terminal:

```bash
ss -tlnp | grep 8443
```

Verify it is responding:

```bash
curl -k https://10.42.17.131:8443/health
```

Open port 8443 on the firewall:

```bash
sudo firewall-cmd --permanent --add-port=8443/tcp
sudo firewall-cmd --reload
```

---

## Part 4 — Server: Configure sshd to trust the CA

First, confirm step-ca is fully ready on the server before proceeding:

```bash
until curl -sk https://10.42.17.131:8443/health | grep -q ok; do
  echo "Waiting for CA..."; sleep 2
done
echo "CA is ready."
```

Get the SSH user CA public key from step-ca running on this server:

```bash
step ssh config --roots > /tmp/ssh_user_ca.pub
cat /tmp/ssh_user_ca.pub
```

```bash
sudo cp /tmp/ssh_user_ca.pub /etc/ssh/ssh_user_ca.pub
sudo chmod 644 /etc/ssh/ssh_user_ca.pub
```

Restore the correct SELinux context:

```bash
sudo restorecon -Rv /etc/ssh/
```

Verify the file exists and has content:

```bash
cat /etc/ssh/ssh_user_ca.pub
```

> **Note:** If the file is missing or empty, re-run the `step ssh config --roots` command above before continuing.

Now modify the SSH server configuration to trust the CA key. Choose one of the following options:

**Option 1 — Backup sshd_config before editing:**

```bash
sudo cp /etc/ssh/sshd_config /etc/ssh/sshd_config.bak
```

Then add the following line to `/etc/ssh/sshd_config`:

```
TrustedUserCAKeys /etc/ssh/ssh_user_ca.pub
```

**Option 2 — Create a drop-in file in sshd_config.d (preferred):**

```bash
echo "TrustedUserCAKeys /etc/ssh/ssh_user_ca.pub" | sudo tee /etc/ssh/sshd_config.d/10-step-ca.conf
sudo restorecon -Rv /etc/ssh/sshd_config.d/
```

> **Note:** Drop-in files in `/etc/ssh/sshd_config.d/` are loaded automatically by sshd and keep the main config file untouched.

Restart sshd:

```bash
sudo systemctl restart sshd
```

Check for SELinux denials if sshd fails to start:

```bash
sudo ausearch -m avc -ts recent | grep sshd
```

---

## Part 5 — Client: Install step-cli

```bash
sudo dnf install -y curl

cat << EOF | sudo tee /etc/yum.repos.d/smallstep.repo
[smallstep]
name=Smallstep
baseurl=https://packages.smallstep.com/stable/fedora/
enabled=1
repo_gpgcheck=0
gpgcheck=1
gpgkey=https://packages.smallstep.com/keys/smallstep-0x889B19391F774443.gpg
EOF

sudo dnf makecache
sudo dnf install -y step-cli
```

---

## Part 6 — Client: Bootstrap trust with the CA

Retrieve the fingerprint on the server if needed:

```bash
step certificate fingerprint $(step path)/certs/root_ca.crt
```

On the client:

```bash
step ca bootstrap \
  --ca-url https://10.42.17.131:8443 \
  --fingerprint <ca-fingerprint>
```

---

## Part 7 — Client: Request an SSH user certificate

```bash
mkdir -p ~/.ssh
chmod 700 ~/.ssh
step ssh certificate $USER@$(hostname) ~/.ssh/id_ed25519 \
  --ca-url https://10.42.17.131:8443 \
  --principal $USER
```

When prompted, select the **JWK** provisioner and enter the provisioner password set in Part 2.

Inspect the certificate:

```bash
step ssh inspect ~/.ssh/id_ed25519-cert.pub
```

---

## Part 8 — Client: Connect to the server

```bash
ssh $USER@10.42.17.131
```

Verify certificate authentication on the **server**:

```bash
sudo journalctl -u sshd | grep "Accepted" | tail -5
```

A successful certificate login will show `ECDSA-CERT` and `CA ECDSA` in the log entry.

### That's it! Great work!

---

## How it works

1. **step-ca starts on the server** — acts as a Certificate Authority, listening on port 8443
2. **sshd is configured to trust the CA** — `TrustedUserCAKeys` tells sshd to accept any user certificate signed by that CA
3. **Client bootstraps trust** — downloads the CA root certificate and stores the CA URL locally
4. **Client requests a certificate** — `step ssh certificate` sends the client's public key to the CA, which signs it and returns a short-lived certificate
5. **Client connects** — SSH presents the certificate instead of a raw key; sshd verifies the CA signature and grants access

> **Note:** The private key never leaves the client. `step ssh certificate` generates the key pair locally and only sends the public key to the CA for signing.

---

## Automation options

The JWK provisioner used in this lab requires a manual password entry. In production environments, the following provisioners remove the manual step:

| Provisioner | Method |
|-------------|--------|
| **OIDC** | User authenticates via SSO (Google, Okta, etc.) and receives a certificate automatically |
| **ACME** | Machine-based certificate issuance with no human interaction |
| **Cloud identity** | AWS, GCP, or Azure instance identity documents used to authenticate |

See the Smallstep documentation for details: https://smallstep.com/docs/step-ca/provisioners/

OIDC provisioners go beyond the scope of this lab. To automate the removal of the password for this lab you could Use the `--no-password --insecure` flags when requesting the certificate:

```
step ssh certificate $USER@$(hostname) ~/.ssh/id_ed25519 \
  --ca-url https://10.42.17.131:8443 \
  --principal $USER \
  --no-password --insecure
```

> However, this is an *insecure* solution! It is only designed to make the lab work without a user having to type the passphrase for the local private key.

## Certificate Renewal in Production

You might ask: *"The certificates are ephemeral. How do we automate the process of getting new certificates?"*

In a production environment the renewal process works like this:

The `step` client has a `renew` command — `step ssh certificate --force` — that silently replaces an existing certificate without user interaction if the provisioner password is stored somewhere accessible, such as a secrets manager or a local file with restricted permissions.

A systemd timer unit is created that fires periodically — typically every few hours — and runs the renewal command. Because certificates are short-lived (often 16-24 hours), the timer is set to renew at roughly the halfway point of the validity period. This ensures there is always a valid certificate in place before the current one expires.

The workflow looks like this:

1. The timer fires
2. `step ssh certificate` runs non-interactively using a stored provisioner password
3. The new certificate replaces the old one in `~/.ssh/`
4. The user's next SSH connection picks up the new certificate automatically

The provisioner password is the sensitive piece. In production it is typically stored in HashiCorp Vault, AWS Secrets Manager, or a similar tool that the renewal script can query programmatically. Some organizations use the OIDC provisioner instead of JWK, which ties renewal to SSO identity — the user's active SSO session is the credential, so no stored password is needed.

## Running step-ca as a systemd Service

By default, step-ca runs in the foreground and stops when the terminal closes or the server reboots. To run it as a persistent service, configure it with systemd.

**Step 1 — Store the CA password in a file:**

```bash
echo "your-ca-password" > $(step path)/password.txt
chmod 600 $(step path)/password.txt
```

**Step 2 — Create the systemd service:**

```bash
sudo tee /etc/systemd/system/step-ca.service << EOF
[Unit]
Description=step-ca Certificate Authority
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
User=$USER
Environment=STEPPATH=$(step path)
ExecStart=/usr/bin/step-ca $(step path)/config/ca.json --password-file=$(step path)/password.txt
Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF
```

**Step 3 — Enable and start:**

```bash
sudo systemctl daemon-reload
sudo systemctl enable --now step-ca
sudo systemctl status step-ca
```

> **Security note:** The password file is plaintext on disk. In production, use a secrets manager such as HashiCorp Vault instead. For a lab this is acceptable.