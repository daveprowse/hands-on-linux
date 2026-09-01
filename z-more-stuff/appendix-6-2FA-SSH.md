# Appendix 6 — Two-Factor Authentication for SSH with libpam-oath

## Overview

This appendix adds TOTP (Time-based One-Time Password) two-factor authentication to SSH using `libpam-oath` and `oathtool`. No Google services are required.

The authentication flow with this configuration:

1. SSH key authenticates (cryptographic, handled by sshd)
2. PAM challenge prompts for a 6-digit OTP
3. Valid OTP grants access — no Unix password required

> **Note:** This appendix is written for Debian. The lab runs on deb1 (10.0.2.51).

---

## Part 1 — Install

```bash
sudo apt install libpam-oath oathtool -y
```

---

## Part 2 — Generate a secret key

Generate a random hex secret that serves as the shared seed for the TOTP algorithm. This secret is used to generate time-based one-time passwords:

```bash
HEX_SECRET=$(head -c 1024 /dev/urandom | openssl sha1 | awk '{print $2}')
echo $HEX_SECRET
```

> **Important:** The `$HEX_SECRET` variable is stored in memory only and is lost when the shell session ends or the server reboots. Copy the value shown by `echo $HEX_SECRET` and store it securely. If the server is restarted, the variable must be restored before generating OTPs:
> ```bash
> HEX_SECRET=<your-saved-hex-value>
> ```

---

## Part 3 — Add the user to the oath users file

The `/etc/users.oath` file is the database that `libpam-oath` uses to validate OTPs. Each line defines a user's authentication method and secret:

```bash
sudo bash -c "echo 'HOTP/T30/6 dave - $HEX_SECRET' > /etc/users.oath"
sudo chmod 600 /etc/users.oath
sudo chown root:root /etc/users.oath
```

- `HOTP/T30/6` — TOTP mode, 30-second window, 6-digit code
- `dave` — the username
- `-` — placeholder for an optional PIN
- `$HEX_SECRET` — the shared secret generated above

> **Note:** Use `>` (overwrite) not `>>` (append) to avoid duplicate entries if re-running after a reboot.

---

## Part 4 — Generate a test OTP to verify

```bash
oathtool --totp -d 6 $HEX_SECRET
```

This generates the current 6-digit OTP. Note it — it changes every 30 seconds.

---

## Part 5 — Configure PAM

Edit `/etc/pam.d/sshd`:

```bash
sudo vim /etc/pam.d/sshd
```

Add at the top (before `@include common-auth`):

```
auth sufficient pam_oath.so usersfile=/etc/users.oath window=30 digits=6
```

> **Note:** `sufficient` means a valid OTP satisfies the PAM stack without also requiring the Unix password. The SSH key is still required — it is enforced by sshd before PAM runs.

---

## Part 6 — Configure sshd_config

Add or set the following in `/etc/ssh/sshd_config`. Place these directives in the Authentication section after `#PermitEmptyPasswords`, above any `Match` blocks:

```
KbdInteractiveAuthentication yes
UsePAM yes
AuthenticationMethods publickey,keyboard-interactive
```

- `KbdInteractiveAuthentication yes` — enables the keyboard-interactive challenge (OTP prompt)
- `UsePAM yes` — tells sshd to use the PAM stack, which loads `pam_oath.so`
- `AuthenticationMethods publickey,keyboard-interactive` — requires both the SSH key AND the OTP in sequence, so a normal `ssh` command triggers both automatically without any special flags

> **Note:** In OpenSSH 10.0 `ChallengeResponseAuthentication` was renamed to `KbdInteractiveAuthentication`. Use the new directive — the old one is ignored.

Place these directives in the Authentication section, above any `Match` blocks.

---

## Part 7 — Validate and restart

```bash
sudo sshd -t
sudo systemctl restart ssh
```

---

## Part 8 — Test

Connect normally from the client — both factors will be required automatically:

```bash
ssh dave@10.0.2.51 -p 2222
```

When prompted for the OTP, generate it on the **server** in a separate terminal:

```bash
oathtool --totp -d 6 $HEX_SECRET
```

Enter the 6-digit code on the client. Access should be granted without a password prompt.

> **Note:** The OTP is only valid for 30 seconds. Generate it and enter it immediately.

---

## After a server reboot

If the server is restarted, restore `$HEX_SECRET` before generating OTPs:

```bash
HEX_SECRET=<your-saved-hex-value>
```

If the `/etc/users.oath` file is intact the secret is already there — you only need the variable restored on the client side for `oathtool` to generate matching OTPs.

---

## Production considerations

For production use, pair this with an authenticator app such as **FreeOTP** or **Aegis** — both are open source and do not require Google services. Generate a QR code from the hex secret to add it to the app:

```bash
oathtool --totp --verbose $HEX_SECRET
```

Use the `Base32 secret` value shown in the output to configure the authenticator app manually, or generate a QR code with a tool such as `qrencode`.

The authenticator app removes the need to run `oathtool` on the command line — users scan once and the app generates OTPs automatically every 30 seconds.

---

## Alternative — Google Authenticator PAM

If you prefer to use the Google Authenticator app instead of a TOTP command line tool, use `libpam-google-authenticator` as an alternative to `libpam-oath`.

### Install

```bash
sudo apt install libpam-google-authenticator -y
```

### Configure for the user

Run as the user who will authenticate:

```bash
google-authenticator
```

Follow the prompts — this generates a QR code to scan with the Google Authenticator app, creates a secret file at `~/.google_authenticator`, and configures TOTP settings.

### Configure PAM

In `/etc/pam.d/sshd`, replace the `pam_oath.so` line with:

```
auth sufficient pam_google_authenticator.so
```

### sshd_config

The same `sshd_config` settings apply:

```
KbdInteractiveAuthentication yes
UsePAM yes
AuthenticationMethods publickey,keyboard-interactive
```

> **Note:** The Google Authenticator PAM module stores the secret per-user in `~/.google_authenticator` rather than a central `/etc/users.oath` file. This makes it simpler for individual user setup but harder to manage centrally across many users.

---

## CentOS Stream Notes

**Package names:**

```bash
sudo dnf install epel-release -y
sudo dnf install pam_oath oathtool -y
```

For Google Authenticator:

```bash
sudo dnf install google-authenticator-libpam -y
```

**PAM config file:**

CentOS uses the same `/etc/pam.d/sshd` file but the include structure differs. Add the `pam_oath.so` line before `auth substack password-auth`:

```
auth sufficient pam_oath.so usersfile=/etc/users.oath window=30 digits=6
auth substack password-auth
```

**SELinux:**

SELinux may block PAM from reading `/etc/users.oath`. Fix with:

```bash
sudo restorecon -Rv /etc/users.oath
```

If still blocked, check for denials:

```bash
sudo ausearch -m avc -ts recent | grep oath
```

**SSH service name:**

```bash
sudo systemctl restart sshd
```