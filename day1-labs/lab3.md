# ⚙️ LAB 3 - Monitoring Linux Hosts Remotely

In this lab we will:

- Forward log messages between Linux systems with `rsyslog`
- Use Prometheus to collect metrics from a remote Linux system

> **Note:** This lab uses Debian 13. CentOS Stream 10 differences are noted inline throughout each section.

---

## Lab 3a — Remote Monitoring with rsyslog

**Estimated time: 20 min**

| Role              | IP        |
|-------------------|-----------|
| Monitoring server | 10.0.2.51 |
| Monitored client  | 10.0.2.52 |

rsyslog is not installed by default on Debian 13 or CentOS Stream 10. Install it first.

**Debian 13:**
```bash
sudo apt install rsyslog
sudo systemctl enable --now rsyslog
```

> **CentOS Stream 10:**
> ```bash
> sudo dnf install rsyslog
> sudo systemctl enable --now rsyslog
> ```

---

### Configure the server to receive logs

On the **server** (10.0.2.51), back up the rsyslog config before editing:

```bash
sudo cp /etc/rsyslog.conf /etc/rsyslog.conf.bak
```

Then edit the file:

```bash
sudo vim /etc/rsyslog.conf
```

Uncomment the following lines to enable UDP and TCP reception:

```
module(load="imudp")
input(type="imudp" port="514")

module(load="imtcp")
input(type="imtcp" port="514")
```

Add a rule to store logs from remote hosts in separate files:

```bash
sudo vim /etc/rsyslog.d/remote.conf
```

```
template(name="RemoteLogs" type="string"
  string="/var/log/remote/%HOSTNAME%/%PROGRAMNAME%.log")
*.* ?RemoteLogs
```

- `%HOSTNAME%` — the hostname of the system that sent the log message
- `%PROGRAMNAME%` — the name of the application or service that generated the message

Create the log directory:

```bash
sudo mkdir -p /var/log/remote
sudo chmod 755 /var/log/remote
```

> **CentOS Stream 10:**
> ```bash
> sudo mkdir -p /var/log/remote
> sudo chmod 755 /var/log/remote
> sudo semanage fcontext -a -t var_log_t "/var/log/remote(/.*)?"
> sudo restorecon -Rv /var/log/remote
> ```
> Install `semanage` if needed:
> ```bash
> sudo dnf install policycoreutils-python-utils
> ```

Restart rsyslog:

```bash
sudo systemctl restart rsyslog
sudo systemctl status rsyslog
```

Open the firewall port:

**Debian 13:**
```bash
sudo ufw allow 514/tcp
sudo ufw allow 514/udp
```

> **CentOS Stream 10:**
> ```bash
> sudo firewall-cmd --permanent --add-port=514/tcp
> sudo firewall-cmd --permanent --add-port=514/udp
> sudo firewall-cmd --reload
> ```
> If rsyslog fails to start, SELinux may be blocking port 514:
> ```bash
> sudo semanage port -a -t syslogd_port_t -p tcp 514
> sudo semanage port -a -t syslogd_port_t -p udp 514
> ```

---

### Configure the client to send logs

On the **client** (10.0.2.52), install rsyslog:

**Debian 13:**
```bash
sudo apt install rsyslog
sudo systemctl enable --now rsyslog
```

> **CentOS Stream 10:**
> ```bash
> sudo dnf install rsyslog
> sudo systemctl enable --now rsyslog
> ```

Edit `/etc/rsyslog.conf`:

```bash
sudo vim /etc/rsyslog.conf
```

Add at the bottom:

```
*.* action(type="omfwd" target="10.0.2.51" port="514" protocol="tcp")
```

> `omfwd` — output module forward. Forwards all log messages to the specified remote host over the network.

Restart rsyslog:

```bash
sudo systemctl restart rsyslog
```

---

### Verify log forwarding

On the **client**, generate a test log:

```bash
logger -t lab-test "Hello from the client"
```

On the **server**, check for the remote log:

```bash
sudo ls /var/log/remote/
sudo tail -f /var/log/remote/deb2/lab-test.log
```

---

## Lab 3b — Remote Monitoring with Prometheus

**Estimated time: 25 min**

Prometheus runs on the **server** (10.0.2.51) and scrapes metrics from node_exporter running on the **client** (10.0.2.52).

Download links:
- Prometheus: https://prometheus.io/download/
- node_exporter: https://prometheus.io/download/#node_exporter

> **Note:** Always download the latest stable version from the links above. Replace `<version>` in the commands below with the version number you download.

---

### Install node_exporter on the client

On the **client** (10.0.2.52):

```bash
cd ~
wget https://github.com/prometheus/node_exporter/releases/download/<version>/node_exporter-<version>.linux-amd64.tar.gz
tar xvf node_exporter-<version>.linux-amd64.tar.gz
cd node_exporter-<version>.linux-amd64
```

Start node_exporter in the foreground:

```bash
./node_exporter
```

Verify it is exposing metrics in a second terminal:

```bash
curl http://localhost:9100/metrics
```

Open the firewall port:

**Debian 13:**
```bash
sudo ufw allow 9100/tcp
```

> **CentOS Stream 10:**
> ```bash
> sudo firewall-cmd --permanent --add-port=9100/tcp
> sudo firewall-cmd --reload
> ```
> If node_exporter fails to bind on port 9100, SELinux may be blocking it:
> ```bash
> sudo semanage port -a -t http_port_t -p tcp 9100
> ```

---

### Install Prometheus on the server

On the **server** (10.0.2.51):

```bash
cd ~
wget https://github.com/prometheus/prometheus/releases/download/<version>/prometheus-<version>.linux-amd64.tar.gz
tar xvf prometheus-<version>.linux-amd64.tar.gz
cd prometheus-<version>.linux-amd64
```

---

### Configure Prometheus to scrape node_exporter

Edit `prometheus.yml` in the extracted directory:

```bash
vim prometheus.yml
```

Replace the contents with:

```yaml
global:
  scrape_interval: 15s

scrape_configs:
  - job_name: 'prometheus'
    static_configs:
      - targets: ['localhost:9090']

  - job_name: 'node_exporter'
    static_configs:
      - targets: ['10.0.2.52:9100']
```

Validate the config file with promtool before starting Prometheus:

```bash
./promtool check config prometheus.yml
```

---

### Start Prometheus

```bash
./prometheus --config.file=prometheus.yml
```

Open the firewall port:

**Debian 13:**
```bash
sudo ufw allow 9090/tcp
```

> **CentOS Stream 10:**
> ```bash
> sudo firewall-cmd --permanent --add-port=9090/tcp
> sudo firewall-cmd --reload
> ```

---

### Access the Prometheus web UI

Open a browser on your host machine and navigate to:

```
http://10.0.2.51:9090
```

---

### Run basic queries in the Prometheus UI

Click **Graph** in the top menu, then enter the following expressions one at a time:

**Check all targets are up:**
```
up
```

> You can also check target status from the terminal on the server:
> ```bash
> curl -s http://localhost:9090/api/v1/query?query=up | python3 -m json.tool
> ```

**Resident memory used by Prometheus itself:**
```
process_resident_memory_bytes{job="prometheus"}
```

**Resident memory used by node_exporter on the client:**
```
process_resident_memory_bytes{job="node_exporter"}
```

**Available disk space on the client:**
```
node_filesystem_avail_bytes{job="node_exporter",mountpoint="/"}
```

**System uptime on the client:**
```
node_time_seconds{job="node_exporter"} - node_boot_time_seconds{job="node_exporter"}
```

> To express uptime in minutes, divide by 60 and enclose the expression in parentheses `()`:
> ```
> (node_time_seconds{job="node_exporter"} - node_boot_time_seconds{job="node_exporter"}) / 60
> ```

Click **Execute** after each query. Switch between the **Table** and **Graph** views to see results.

🎉 **That's the end of Lab 3! You ROCK!**

---

## Estimated Time Summary

| Lab | Task | Time |
|-----|------|------|
| 3a | rsyslog server and client setup | 20 min |
| 3b | Prometheus + node_exporter | 25 min |
| Buffer | Questions and troubleshooting | 5 min |
| **Total** | | **~50 min** |

---

## Troubleshooting

**rsyslog not receiving remote logs:**
```bash
sudo ss -tlnp | grep 514
sudo journalctl -u rsyslog -n 20
```

**Prometheus can't reach node_exporter:**
```bash
curl http://10.0.2.52:9100/metrics
```
Confirm the firewall port 9100 is open on the client.

**Prometheus web UI not reachable:**
```bash
curl http://localhost:9090
```
Confirm Prometheus is still running in the foreground terminal.

**No data in Prometheus queries:**
Wait at least one scrape interval (15 seconds) after starting both services before running queries.