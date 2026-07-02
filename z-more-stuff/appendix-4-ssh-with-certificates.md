# Appendix 4 — SSH with Certificates

> Note: This can be a difficult lab with a lot of twists and turns that could cause failures. Proceed with caution and patience!
> 
> In the field, most large environments will use a vault program (such as HashiCorp Vault) or something like SmallStep. 
> 
> SMALLSTEP lab Link
> 
> If you are interested in HashiCorp Vault, see my video course [here](https://learning.oreilly.com/course/hashicorp-certified-vault/9780138312923/).

## Overview

SSH certificates are the modern approach for larger environments. Instead of distributing public keys to every server, a Certificate Authority (CA) signs user keys. Any server that trusts the CA will accept the certificate without needing the individual public key.

In this lab we will manually create a local CA and sign the client's key.

| Role   | IP        |
|--------|-----------|
| Server | 10.0.2.51 |
| Client | 10.0.2.52 |

---

## Step 1 — Create the CA key pair on the server

On the **server** VM:

```bash
sudo mkdir -p /etc/ssh/ca
sudo chmod 700 /etc/ssh/ca
sudo ssh-keygen -t ed25519 -f /etc/ssh/ca/ssh_ca -C "lab-ca" -N ""
```

This creates:
- `/etc/ssh/ca/ssh_ca` — CA private key
- `/etc/ssh/ca/ssh_ca.pub` — CA public key

---

## Step 2 — Configure the server to trust the CA

```bash
sudo cp /etc/ssh/ca/ssh_ca.pub /etc/ssh/
```

Edit `/etc/ssh/sshd_config` and add:

```
TrustedUserCAKeys /etc/ssh/ssh_ca.pub
```

Restart SSH:

**Debian 13:**
```bash
sudo systemctl restart ssh
```

**CentOS Stream 10:**
```bash
sudo systemctl restart sshd
```

---

## Step 3 — Remove the client's public key from authorized_keys

Since the client's public key was added in Lab 2b, remove it from the server to ensure certificate authentication is used:

```bash
# On server
sed -i '/lab-key/d' ~/.ssh/authorized_keys
```

Verify:
```bash
cat ~/.ssh/authorized_keys
```

---

## Step 4 — Copy the CA public key to the client

On the **server**, display the CA public key:

```bash
sudo cat /etc/ssh/ca/ssh_ca.pub
```

On the **client**, copy it to a file:

```bash
mkdir -p ~/.ssh
nano ~/.ssh/ssh_ca.pub
# paste the CA public key, save and exit
```

---

## Step 5 — Sign the client's public key

Copy the client's public key to the server:

```bash
# On client
scp ~/.ssh/id_ed25519.pub dave@10.0.2.51:/tmp/client.pub
```

On the **server**, sign the key with the CA:

```bash
sudo ssh-keygen -s /etc/ssh/ca/ssh_ca \
  -I "dave-lab" \
  -n dave \
  -V +1w \
  /tmp/client.pub
```

- `-s` — CA key to sign with
- `-I` — certificate identity (label)
- `-n` — principals (valid usernames)
- `-V +1w` — valid for 1 week

This creates `/tmp/client-cert.pub`. Copy it back to the client:

```bash
# On server
scp /tmp/client-cert.pub dave@10.0.2.52:~/.ssh/id_ed25519-cert.pub
```

Set correct permissions on the client:

```bash
# On client
chmod 600 ~/.ssh/id_ed25519-cert.pub
```

---

## Step 6 — Load the key and certificate into the agent

```bash
# On client
ssh-add ~/.ssh/id_ed25519
```

> Note: This loads both the private key and the certificate into the agent simultaneously.

Verify both are loaded:

```bash
ssh-add -l
```

You should see both an `ED25519` and an `ED25519-CERT` entry.

---

## Step 7 — Verify the certificate

```bash
# On client
ssh-keygen -L -f ~/.ssh/id_ed25519-cert.pub
```

Confirm the validity period, principals, and signing CA fingerprint.

---

## Step 8 — Connect using the certificate

```bash
ssh dave@10.0.2.51
```

Verify certificate authentication was used on the **server**:

```bash
sudo journalctl -u ssh | grep "Accepted" | tail -5
```

A successful certificate login will show `ED25519-CERT` in the log entry.

> **Why certificates?** In environments with many servers, certificates eliminate the need to distribute `authorized_keys` to each one. Any server configured with `TrustedUserCAKeys` will accept any certificate signed by that CA. Certificate expiry also enforces time-limited access without manual key removal.