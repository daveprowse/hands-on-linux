# Appendix 7 — firewalld FreeIPA Zone Configuration

## Overview

This appendix shows what a real-world locked-down firewalld zone configuration file looks like for a FreeIPA identity management server. It demonstrates how to define a custom zone, set it as the default, and restrict all traffic except what FreeIPA requires.

Zone config files live in `/etc/firewalld/zones/` and are named after the zone. Anything not explicitly listed in the zone file is rejected by default — there is no need to add a blanket block rule.

---

## Step 1 — Create the zone file

Create `/etc/firewalld/zones/freeipa.xml`:

```bash
sudo vim /etc/firewalld/zones/freeipa.xml
```

```xml
<?xml version="1.0" encoding="utf-8"?>
<zone target="DROP">
  <short>freeipa</short>
  <description>Locked-down zone for a FreeIPA identity management server. All traffic is dropped unless explicitly listed below.</description>
  <port protocol="tcp" port="22"/>      <!-- SSH - admin access -->
  <port protocol="tcp" port="80"/>      <!-- HTTP - redirect to HTTPS -->
  <port protocol="tcp" port="88"/>      <!-- Kerberos -->
  <port protocol="udp" port="88"/>      <!-- Kerberos -->
  <port protocol="tcp" port="389"/>     <!-- LDAP -->
  <port protocol="tcp" port="443"/>     <!-- HTTPS - web UI and API -->
  <port protocol="tcp" port="464"/>     <!-- Kerberos password change -->
  <port protocol="udp" port="464"/>     <!-- Kerberos password change -->
  <port protocol="tcp" port="53"/>      <!-- DNS -->
  <port protocol="udp" port="53"/>      <!-- DNS -->
  <port protocol="tcp" port="636"/>     <!-- LDAPS -->
</zone>
```

> **Note — zone targets:** The `target` attribute controls what happens to traffic not explicitly listed in the zone:
>
> | Target | Behavior |
> |--------|---------|
> | *(none)* or `%%REJECT%%` | **Reject** — sends an ICMP "admin prohibited" response back to the sender |
> | `DROP` | **Drop** — silently discards packets with no response. The sender gets no feedback and must wait for a timeout |
> | `ACCEPT` | **Accept** — allows all unlisted traffic through (insecure, rarely used) |
>
> `DROP` is the more secure choice for a production server — it gives attackers no information about whether the host is alive or filtered.

---

## Step 2 — Reload firewalld to load the new zone

```bash
sudo firewall-cmd --reload
```

Verify the new zone is available:

```bash
sudo firewall-cmd --get-zones | grep freeipa
```

---

## Step 3 — Assign the interface to the freeipa zone

```bash
sudo firewall-cmd --zone=freeipa --change-interface=enp1s0 --permanent
sudo firewall-cmd --reload
```

---

## Step 4 — Set freeipa as the default zone

```bash
sudo firewall-cmd --set-default-zone=freeipa
firewall-cmd --get-default-zone
```

---

## Step 5 — Verify

```bash
sudo firewall-cmd --list-all --zone=freeipa
```

Only the listed ports should be shown. All other traffic will be rejected.

---

> Note that FreeIPA is the Fedora name. It is also known as CentOS Identity Management or RedHat Identity Management depending on which distro you use.

> **Reference:** 
>
> Official FreeIPA firewall documentation: 
> 
> https://www.freeipa.org/page/Firewall
>
> For an in-depth step-by-step installation of FreeIPA on the server and the client side, see my video at: 
>
> https://www.youtube.com/watch?v=8ywLsrBwqxA