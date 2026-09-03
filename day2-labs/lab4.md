# ⚙️ LAB 4 — Firewalling Linux

In this lab we will:

- Configure firewalld on CentOS to control inbound access
- Build a custom nftables ruleset on Debian from scratch
- Demonstrate panic mode in firewalld
- Make firewall rules persistent

> **Note:** Lab 4a runs on CentOS, centos1 (10.0.2.71). Lab 4b runs on Debian, deb2 (10.0.2.52).

---

## Estimated Time Summary

| Lab | Task | Time |
|-----|------|------|
| 4a | firewalld on CentOS | 25 min |
| 4b | nftables on Debian | 25 min |
| Buffer | Q&A | 5 min |
| **Total** | | **~55 min** |

---

## Lab 4a — Configuring firewalld

**Estimated time: 25 min**

firewalld is the default firewall management tool on CentOS, RHEL, and Fedora. It acts as a front-end to the netfilter framework via nftables under the hood. It uses the concept of **zones** — pre-defined security levels that determine what traffic is allowed.

> **Debian/Ubuntu note:** firewalld can be installed on Debian but is not the native tool and may behave unexpectedly. Install and start it with:
> ```bash
> sudo apt install firewalld
> sudo systemctl enable --now firewalld
> ```
> The config files on Debian live in the same location as CentOS — see the configuration files section at the end of this lab.

---

### Check firewalld status

```bash
systemctl status firewalld
```

If not running, start and enable it:

```bash
sudo systemctl enable --now firewalld
```

Check the firewalld version:

```bash
firewall-cmd --version
```

---

### View the current zone

Zones hold different security configurations. Common built-in zones include `public`, `block`, `drop`, and `trusted`.

```bash
firewall-cmd --get-active-zones
```

Get detailed information about the active zone:

```bash
firewall-cmd --list-all
```

Note the services currently allowed — typically `ssh`, `dhcpv6-client`, and `cockpit` on a fresh CentOS install.

View all available zones:

```bash
firewall-cmd --get-zones
firewall-cmd --list-all-zones
```

---

### Test connectivity before locking down

From another system, verify you can ping and SSH into centos1:

```bash
ping 10.0.2.71
ssh user@10.0.2.71
```

---

### Test browser connectivity to Cockpit

From another system, open a browser and navigate to:

```
https://10.0.2.71:9090
```

Accept the browser security warning and continue. Log in with your CentOS user account credentials. Cockpit should load successfully — for now!

---

### Change the active zone to block

The `block` zone rejects all inbound connections by default.

Find your interface name:

```bash
ip link show
```

Change the active zone:

```bash
sudo firewall-cmd --zone=block --change-interface=enp1s0 --permanent
firewall-cmd --get-active-zones
```

> Replace `enp1s0` with your actual interface name.

Verify the block zone is active:

```bash
sudo firewall-cmd --zone=block --list-all
```

No services or ports should be listed. Test from a remote system — ping and SSH should both fail.

Scan the server with nmap from another system:

```bash
nmap -Pn 10.0.2.71
```

> **Note:** If nmap is not installed: `sudo apt install nmap` (Debian) or `sudo dnf install nmap` (CentOS).

> **Note:** The scan may take a minute or two to complete — nmap probes all ports and filtered responses take longer than closed ones.

All ports should show as filtered.

---

### Change the default zone

The default zone is used for any interface not explicitly assigned to another zone. Change it to `block`:

```bash
sudo firewall-cmd --set-default-zone=block
firewall-cmd --get-default-zone
```

> **Note:** Changing the default zone takes effect immediately and does not require `--reload` or `--permanent`.

---

### Add a rule to allow SSH

```bash
sudo firewall-cmd --add-port=22/tcp --permanent
sudo firewall-cmd --reload
sudo firewall-cmd --list-all
```

Test from a remote system — SSH should now work, ping should still fail.

---

### Open multiple ports at once

```bash
sudo firewall-cmd --add-port={80,443,8080}/tcp --permanent
sudo firewall-cmd --reload
sudo firewall-cmd --list-ports
```

Remove them:

```bash
sudo firewall-cmd --remove-port={80,443,8080}/tcp --permanent
sudo firewall-cmd --reload
```

---

### Panic mode

Panic mode immediately drops all inbound and outbound traffic — a kill switch for network access.

> **Warning:** Only use this when working directly at the console. Enabling panic mode will drop all SSH connections immediately.

Enable panic mode:

```bash
sudo firewall-cmd --panic-on
```

Check the status:

```bash
sudo firewall-cmd --query-panic
```

From another system, try to SSH in — it should fail immediately with a connection timeout.

Disable panic mode:

```bash
sudo firewall-cmd --panic-off
```

> **Use case:** Panic mode is useful when a server is actively being attacked and you need to immediately cut all network access while you investigate.

---

### Restore the original zone

Change the interface back to the original zone first:

```bash
sudo firewall-cmd --zone=public --change-interface=enp1s0 --permanent
sudo firewall-cmd --reload
sudo firewall-cmd --get-active-zones
```

Then change the default zone back to public:

```bash
sudo firewall-cmd --set-default-zone=public
firewall-cmd --get-default-zone
```

> Replace `public` with your original zone name if different.

From another system, verify all services are accessible again:

```bash
ping 10.0.2.71
ssh user@10.0.2.71
```

Also try connecting to Cockpit in the browser at `https://10.0.2.71:9090` — ping, SSH, and Cockpit should all work again.

---

### firewalld configuration files

| Location | Distro | Purpose |
|----------|--------|---------|
| `/etc/firewalld/` | Both | User-defined and modified zone configs |
| `/usr/lib/firewalld/zones/` | Both | Default read-only zone definitions |
| `/etc/firewalld/firewalld.conf` | Both | Main firewalld configuration |

> **Real-World Config:** If you would like to see an actual firewalld zone file configuration for use with FreeIPA identity management servers, check out [Appendix 7](../z-more-stuff/appendix-7-firewalld-freeipa-zone-config.md).

---

## Lab 4b — Configuring nftables

**Estimated time: 25 min**

nftables is the modern replacement for iptables, built directly into the Linux kernel. It uses a **Tables > Chains > Rules** hierarchy.

> **Important:** Work directly at the VM console for this lab. Adding a default-drop chain will cut SSH access.

> **CentOS note:** nftables is available on CentOS via `sudo dnf install nftables`. The config file is `/etc/sysconfig/nftables.conf` rather than `/etc/nftables.conf`.

---

### Install and start nftables

**Debian:**
```bash
sudo apt install nftables
sudo systemctl enable --now nftables
sudo systemctl status nftables
```

---

### View the current ruleset

```bash
sudo nft list ruleset
```

The default ruleset has all traffic open — no restrictions.

---

### Enter the nft interactive shell

```bash
sudo nft -i
```

All commands below are entered at the `nft>` prompt — omit the leading `nft` prefix.

---

### Create a new table

```bash
add table inet ports_table
list ruleset
```

You should see the new empty `ports_table` alongside the default table.

---

### Create a secure input chain

```bash
add chain inet ports_table input { type filter hook input priority 0 ; policy drop ; }
```

This drops all inbound traffic. Test from a remote system — ping and SSH should immediately fail.

---

### Allow SSH

```bash
add rule inet ports_table input tcp dport 22 accept
list ruleset
```

Test from a remote system — SSH should now work.

> **Note:** You can also use the service name: `tcp dport ssh accept`

---

### Allow ICMP (ping)

```bash
add rule inet ports_table input icmp type echo-request accept
add rule inet ports_table input icmp type echo-reply accept
```

Test ping from a remote system.

> **Note:** `echo-request` allows other systems to ping this Debian host — it accepts incoming ping requests. `echo-reply` allows this Debian host to receive replies when it pings out — without it, outbound pings initiated from this system would get no response back. Both are needed for full two-way ping functionality.

---

### View the complete ruleset

```bash
list ruleset
```

Exit the interactive shell:

```bash
quit
```

---

### Save the configuration

Back up the current config:

```bash
sudo cp /etc/nftables.conf /etc/nftables.conf.bak
```

Save the new ruleset:

```bash
sudo nft list ruleset | sudo tee /etc/nftables.conf
```

Restart nftables:

```bash
sudo systemctl restart nftables
```

Reboot and verify the ruleset persists:

```bash
sudo reboot
```

After reboot:

```bash
sudo nft list ruleset
```

---

### Restore the original configuration

```bash
sudo cp /etc/nftables.conf.bak /etc/nftables.conf
sudo systemctl restart nftables
sudo nft list ruleset
```

The original open ruleset should be restored.

---

### nftables configuration files

| Location | Distro | Purpose |
|----------|--------|---------|
| `/etc/nftables.conf` | Debian/Ubuntu | Main nftables configuration loaded at boot |
| `/etc/sysconfig/nftables.conf` | CentOS/RHEL | Bootstrap file loaded by systemd — contains `include` statements pointing to the active ruleset file |
| `/etc/nftables/` | CentOS/RHEL | Directory containing the actual ruleset files included by `/etc/sysconfig/nftables.conf` |

> **CentOS nftables file structure:** The `/etc/nftables/` directory contains several template files:
> - `main.nft` — the default active ruleset, included by `/etc/sysconfig/nftables.conf`
> - `nat.nft` — NAT rules template, included but empty by default
> - `router.nft` — router and forwarding rules template, included but empty by default
>
> To use a custom ruleset, create a new `.nft` file in `/etc/nftables/` and update the `include` line in `/etc/sysconfig/nftables.conf` to point to it:
> ```
> include "/etc/nftables/custom.nft"
> ```
>
> **Note:** Regular users cannot list or navigate into `/etc/nftables/` directly. Use `sudo -i` to open a root shell first, or prefix file operations with `sudo`.

---

## Resources

- nftables Wiki: https://wiki.nftables.org
- nftables simple rule management: https://wiki.nftables.org/wiki-nftables/index.php/Simple_rule_management
- firewalld documentation: https://firewalld.org/documentation/
- `man nft` — full nftables reference
- `man firewall-cmd` — full firewalld reference

- Linux Security - Basics & Beyond Video Course: https://learning.oreilly.com/course/linux-security-/9780135338001/
---

# 🎉 That's the end of Lab 4 — and the end of Day 2! Outstanding work!