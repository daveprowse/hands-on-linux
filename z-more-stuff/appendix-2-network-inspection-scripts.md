# Appendix 2 — Network Inspection Scripts

Two bash scripts are provided to automate the network inspection commands covered in Lab 1. They produce timestamped report files that can be reviewed after the lab session.

| Script | Purpose | Output |
|--------|---------|--------|
| `local-stats.sh` | Collects local interface, routing, and socket data | `report-local-stats-TIMESTAMP.txt` |
| `net-inspect.sh` | Scans a remote target and captures traffic | `inspection-report-TIMESTAMP.txt`, `capture-TIMESTAMP.pcap` |

---

## Step 1 — Make the scripts executable

After downloading or copying the scripts, set the execute permission on both:

```bash
chmod +x local-stats.sh net-inspect.sh
```

Verify the permissions:

```bash
ls -l local-stats.sh net-inspect.sh
```

You should see an `x` in the permissions column for both files, for example:

```
-rwxr-xr-x 1 dave dave 1234 Jun 23 10:00 local-stats.sh
-rwxr-xr-x 1 dave dave 2345 Jun 23 10:00 net-inspect.sh
```

---

## Step 2 — Run local-stats.sh

This script requires `sudo` to access socket and process information:

```bash
sudo ./local-stats.sh
```

The script will:
1. Display a 5-second countdown before starting
2. Install any missing required packages
3. Collect local interface, routing, and socket data
4. Save the results to `report-local-stats-TIMESTAMP.txt`
5. Display a completion message with the filename

---

## Step 3 — Run net-inspect.sh

This script requires `sudo` and a target IP address as an argument:

```bash
sudo ./net-inspect.sh 10.0.2.52
```

Replace `10.0.2.52` with the IP address of the system you want to inspect.

The script will:
1. Display a 5-second countdown before starting
2. Install any missing required packages
3. Start a background packet capture immediately
4. Run nmap, fping, nc, arping, and dig against the target
5. Stop the packet capture when the inspection is complete
6. Save the inspection report to `inspection-report-TIMESTAMP.txt`
7. Save the packet capture to `capture-TIMESTAMP.pcap`
8. Display a completion message with all filenames

---

## Step 4 — Review the output files

List the generated files:

```bash
ls -lh report-local-stats-*.txt inspection-report-*.txt capture-*.pcap
```

View a report:

```bash
less report-local-stats-TIMESTAMP.txt
less inspection-report-TIMESTAMP.txt
```

Read the packet capture:

```bash
sudo tcpdump -r capture-TIMESTAMP.pcap
```

Open the packet capture in Wireshark for deeper analysis:

```bash
wireshark capture-TIMESTAMP.pcap
```

> **Note:** Replace `TIMESTAMP` with the actual date/time string in your filename, for example `report-local-stats-20260623-102500.txt`.

---

## Distro Notes

Both scripts automatically detect the package manager and install required tools. No manual package installation is needed.

| Distro | Package Manager | Packages Installed |
|--------|-----------------|--------------------|
| Debian 13 / Ubuntu 26.04 | `apt` | `iproute2`, `lsof`, `nmap`, `fping`, `netcat-openbsd`, `arping`, `tcpdump` |
| CentOS Stream 10 | `dnf` | `iproute`, `lsof`, `nmap`, `fping`, `nmap-ncat`, `iputils`, `tcpdump` |