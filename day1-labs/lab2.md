# ⚙️ LAB 2 - Connecting Between Hosts in the Command Line

In this lab we wll show how to:

- SSH from a client to a server using passwords
- SSH from a client to a server using keys
- Use `rsync` to move/copy data from one host to another over an SSH connection

## Lab 2a - SSH from Client to Server

**Estimated time: 10 min**

Both VMs must be running and reachable on `10.0.2.0/24`.

| Role   | IP         |
|--------|------------|
| Server | 10.0.2.51  |
| Client | 10.0.2.52  |

### Install OpenSSH server on the server VM

**Debian 13:**
```bash
sudo apt install openssh-server
sudo systemctl enable --now ssh
sudo systemctl status ssh
```

**CentOS Stream 10:**
```bash
sudo dnf install openssh-server
sudo systemctl enable --now sshd
sudo systemctl status sshd
```

### Verify the SSH port is open on the server

```bash
ss -tlnp | grep 22
```

### Connect from client to server

On the **client** VM:

```bash
ssh dave@10.0.2.51
```

Replace `dave` with your actual username on the server. Accept the host key fingerprint when prompted. Verify the connection:

```bash
hostname
ip a
```

Both should confirm you are on the server. Exit:

```bash
exit
```

### Run a remote command without opening a shell

```bash
ssh dave@10.0.2.51 "hostname && uptime"
```

---

## Lab 2b - SSH with Keys

**Estimated time: 13 min**

Key-based authentication removes the need for passwords and is the standard for production systems. OpenSSH 10.0 on Debian 13 and CentOS Stream 10 defaults to ed25519.

### Generate an ed25519 key pair on the client

On the **client** VM:

```bash
ssh-keygen -t ed25519 -C "lab-key"
```

Accept the default location (`~/.ssh/id_ed25519`). Set a passphrase when prompted — this is recommended even in a lab.

View the generated files:

```bash
ls -l ~/.ssh/
```

You should see:
- `id_ed25519` — private key (never share this)
- `id_ed25519.pub` — public key (this is what goes to the server)

### Copy the public key to the server

```bash
ssh-copy-id dave@10.0.2.51
```

This appends the public key to `~/.ssh/authorized_keys` on the server.

### Connect using the key

```bash
ssh dave@10.0.2.51
```

You should be prompted for your key passphrase instead of your account password.

> Note: If you had more than one key in `.ssh` (which is quite likely) you could specify a key with `ssh -i ~/.ssh/<key_name> user@<ip_address>`. You could also create aliases within the `config` file in `.ssh`.

---

> ### SSH Certificates
>
> You can also connect by way of SSH certificates - the newer standard. SSH certificates are SSH keys that have been signed by a trusted Certificate Authority, allowing servers to grant access based on CA trust rather than storing individual public keys in `authorized_keys`.
>
> This is an in-depth process, and too time-consuming for this lab, but I wrote out a separate step-by-step lab for you. There are separate lab documents in Appendix 5 for [Debian](../z-more-stuff/appendix-5a-debian-ssh-certificates-with-smallstep.md) and for [CentOS](../z-more-stuff/appendix-5b-centos-ssh-certificates-with-smallstep.md). Enjoy!

---

## Lab 2c - Using rsync to Transfer Data

**Estimated time: 12 min**

### Install rsync on both VMs

**Debian 13:**
```bash
sudo apt install rsync
```

**CentOS Stream 10:**
```bash
sudo dnf install rsync
```

Verify:
```bash
rsync --version
```

### Create test files on the client

```bash
mkdir -p ~/lab-files
for i in {1..5}; do echo "Test file $i" > ~/lab-files/file${i}.txt; done
ls ~/lab-files/
```

### Copy a single file to the server

```bash
rsync -v ~/lab-files/file1.txt dave@10.0.2.51:~/
```

`-v` — verbose output.

### Copy a directory to the server

```bash
rsync -av ~/lab-files/ dave@10.0.2.51:~/lab-files/
```

`-a` — archive mode: preserves permissions, timestamps, symlinks, and owner. `-v` — verbose.

### Incremental sync — only changed files

Modify a file on the client:

```bash
echo "Modified" >> ~/lab-files/file1.txt
```

Run rsync again:

```bash
rsync -av ~/lab-files/ dave@10.0.2.51:~/lab-files/
```

Only `file1.txt` is transferred — rsync compares checksums and skips unchanged files.

### Dry run — preview without transferring

```bash
rsync -av --dry-run ~/lab-files/ dave@10.0.2.51:~/lab-files/
```

`--dry-run` shows what would be transferred without making any changes. Useful before a large sync.

### Delete files on the destination that no longer exist on the source

```bash
rm ~/lab-files/file5.txt
rsync -av --delete ~/lab-files/ dave@10.0.2.51:~/lab-files/
```

`--delete` removes files from the destination that have been deleted on the source. Use with caution.

> **Note:** Use `-P` to show `--progress` and `--partial`. That will show the progress bar but also, can resume file transfers if there is a stop or error. I use it all the time!

> **Note:** rsync uses SSH as its transport by default when a remote host is specified. No additional configuration is needed if key-based SSH authentication is already working.
>
> **Note:** You can also use `rsync://` as the method of transfer instead of SSH. For example, locally:
> 
> `rsync rsync://localhost/source/ /destination/`
>
> or, remotely:
>
> `rsync rsync://source-ip/videos/ /destination/path/`
> 
> However, this requires an rsync daemon running locally with the source configured as a module in `/etc/rsyncd.conf`. Example:
>
> ```
> [videos]
> path = /path/to/mp4s
> read only = yes
> ```
>
>If you have a lot of data, this could provide for a faster and more stable transfer than running within SSH (which is prone to failure when transferring large amounts of data). But we are gaining speed and stability at the cost of security, as the rsync daemon will skip encryption entirely. That said, it can be beneficial on an *isolated, trusted* network (and especially running internally between drives).

---

## Estimated Time Summary

| Lab | Task | Time |
|-----|------|------|
| 2a | SSH from client to server | 10 min |
| 2b | SSH with keys | 13 min |
| 2c | rsync | 12 min |
| Buffer | Questions and troubleshooting | 10 min |
| **Total** | | **~45 min** |

---

## Troubleshooting

**Permission denied (publickey):**
```bash
ssh -v dave@10.0.2.51
```
Verbose output will show which keys are being offered and why they are rejected.

**`~/.ssh/authorized_keys` permissions too open:**
```bash
chmod 700 ~/.ssh
chmod 600 ~/.ssh/authorized_keys
```

**Certificate principal mismatch:**
The `-n` flag when signing must match the username on the server. Re-sign with the correct principal if needed.

**rsync: connection unexpectedly closed:**
Confirm SSH key authentication is working before using rsync. rsync over SSH inherits the same authentication.

**CentOS — SELinux blocking SSH key authentication:**
```bash
sudo restorecon -Rv ~/.ssh
```