# ⚙️ LAB 4 - Docker Networking

In this lab we will:

- Install Docker Engine and inspect the default bridge network
- Create a custom bridge network
- Demonstrate container-to-container communication
- Map container ports to the host

> **Note:** This lab runs on a single VM at 10.0.2.51 using Debian 13. CentOS Stream 10 differences are noted inline.

Let's go! 

---

## Lab 4a — Install Docker and Inspect the Bridge

**Estimated time: 10 min**

### Remove any conflicting packages

```bash
sudo apt remove docker docker-engine docker.io containerd runc 2>/dev/null
```

> **CentOS Stream 10:**
> ```bash
> sudo dnf remove docker docker-client docker-client-latest docker-common \
>   docker-latest docker-latest-logrotate docker-logrotate docker-engine 2>/dev/null
> ```

### Add Docker's official repository

```bash
sudo apt install -y ca-certificates curl
sudo install -m 0755 -d /etc/apt/keyrings
sudo curl -fsSL https://download.docker.com/linux/debian/gpg \
  -o /etc/apt/keyrings/docker.asc
sudo chmod a+r /etc/apt/keyrings/docker.asc

sudo tee /etc/apt/sources.list.d/docker.sources << EOF
Types: deb
URIs: https://download.docker.com/linux/debian
Suites: $(. /etc/os-release && echo "$VERSION_CODENAME")
Components: stable
Architectures: $(dpkg --print-architecture)
Signed-By: /etc/apt/keyrings/docker.asc
EOF

sudo apt update
```

> **CentOS Stream 10:**
> ```bash
> sudo dnf install -y dnf-plugins-core
> sudo dnf config-manager --add-repo \
>   https://download.docker.com/linux/centos/docker-ce.repo
> ```

### Install Docker Engine

```bash
sudo apt install -y docker-ce docker-ce-cli containerd.io \
  docker-buildx-plugin docker-compose-plugin
```

> **CentOS Stream 10:**
> ```bash
> sudo dnf install -y docker-ce docker-ce-cli containerd.io \
>   docker-buildx-plugin docker-compose-plugin
> ```

### Start Docker and add user to docker group

```bash
sudo systemctl enable --now docker
sudo usermod -aG docker $USER
newgrp docker
```

### Verify the installation

```bash
docker version
docker run hello-world
```

### Inspect the default bridge network

List all Docker networks:

```bash
docker network ls
```

Inspect the default `bridge` network:

```bash
docker network inspect bridge
```

Note the subnet (typically `172.17.0.0/16`) and gateway assigned by Docker.

> You can also view Docker network interfaces on the host:
> ```bash
> ip a | grep docker
> ```

Run a container and check its IP:

```bash
docker run -d --name container1 alpine sleep 300
docker inspect container1 | grep IPAddress
```

---

## Lab 4b — Create a Custom Bridge Network

**Estimated time: 8 min**

The default bridge network does not support container name resolution. A custom bridge network does — containers on the same custom network can reach each other by name.

Create a custom bridge network with an explicit subnet:

```bash
docker network create \
  --driver bridge \
  --subnet 172.20.0.0/24 \
  --gateway 172.20.0.1 \
  labnet
```

Verify it was created:

```bash
docker network ls
docker network inspect labnet
```

> **Note:** With a `/24` subnet, `labnet` has 254 usable addresses — `172.20.0.1` to `172.20.0.254`. `172.20.0.0` is the network address and `172.20.0.255` is the broadcast address, both unusable. Additional isolated networks can be created on separate subnets — `172.20.1.0/24`, `172.20.2.0/24`, and so on — each with their own 254 usable addresses.

---

## Lab 4c — Container-to-Container Communication

**Estimated time: 12 min**

### Launch two containers on the custom network

```bash
docker run -d --name webserver --network labnet nginx:alpine
docker run -d --name client --network labnet alpine sleep 300
```

### Ping by IP

Get the webserver's IP:

```bash
docker inspect webserver | grep IPAddress
```

Ping from client by IP:

```bash
docker exec client ping -c 3 <webserver-IP>
```

### Ping and curl by name

On a custom bridge network, Docker provides built-in DNS resolution by container name:

```bash
docker exec client ping -c 3 webserver
docker exec client wget -qO- http://webserver
```

The `wget` command should return the nginx welcome page, confirming HTTP traffic flows between containers by name.

### Demonstrate network isolation

Run a container on the default bridge:

```bash
docker run -d --name isolated alpine sleep 300
```

Attempt to reach `webserver` from the isolated container:

```bash
docker exec isolated ping -c 3 webserver
```

This will fail — containers on different networks cannot communicate by default. This is Docker's network isolation in action.

---

## Lab 4d — Port Mapping to the Host

**Estimated time: 8 min**

### First, show that a container is not reachable without port mapping

Run an nginx container on `labnet` without a published port:

```bash
docker run -d --name webapp --network labnet nginx:alpine
```

Try to reach it from the host:

```bash
curl http://localhost:80
```

This will fail — the container's port 80 is not exposed to the host. This is the expected result.

### Now run the container with a published port

Remove the previous container and re-run with port mapping:

```bash
docker rm -f webapp
docker run -d --name webapp --network labnet -p 8080:80 nginx:alpine
```

This maps port `8080` on the host to port `80` inside the container.

### Verify from the host

```bash
curl http://localhost:8080
```

Should return the nginx welcome page.

### Inspect the port mapping

```bash
docker port webapp
docker ps
```

---

> **🔒 Open the host firewall to allow external access**
>
> **Debian 13:**
> ```bash
> sudo ufw allow 8080/tcp
> ```
>
> **CentOS Stream 10:**
> ```bash
> sudo firewall-cmd --permanent --add-port=8080/tcp
> sudo firewall-cmd --reload
> ```
>
> Test from your host machine browser:
> ```
> http://10.0.2.51:8080
> ```

---

---

## Cleanup

```bash
docker stop container1 webserver client isolated webapp
docker rm container1 webserver client isolated webapp
docker network rm labnet
```

🎉 **That's the end of Lab 4! You are now a Docker networking pro!**

---

## Estimated Time Summary

| Lab | Task | Time |
|-----|------|------|
| 4a | Install Docker, inspect bridge | 10 min |
| 4b | Create custom bridge network | 8 min |
| 4c | Container-to-container communication | 12 min |
| 4d | Port mapping to the host | 8 min |
| Buffer | Questions and troubleshooting | 7 min |
| **Total** | | **~45 min** |

---

## ⭐ Extra Credit — Run a Web App on the Default Bridge

If there is time left, try this fun one-liner that spins up a fully working web game inside a container on the default bridge and maps it to the host:

```bash
docker run -d --name 2048 -p 8888:80 neusinn/docker-2048
```

Open a browser on your host machine and navigate to:

```
http://10.0.2.51:8888
```

You should see a fully playable 2048 game running inside a Docker container. When done:

```bash
docker stop 2048 && docker rm 2048
```

---

## ⭐⭐ Extra Extra Credit — Docker Network Drivers

Docker supports six network drivers:

**bridge** — the default. Creates a virtual switch on the host. Containers get private IPs and communicate through it. NAT handles external traffic.

**host** — removes network isolation. Container shares the host's network stack directly. No virtual interface, no NAT, no port mapping needed.

**none** — disables all networking. Container has only a loopback interface. Used for maximum isolation.

**overlay** — spans multiple Docker hosts. Used with Docker Swarm to connect containers across machines as if they were on the same network.

**macvlan** — assigns a real MAC address to the container, making it appear as a physical device on the network. Containers get IPs directly from the LAN subnet. Useful when containers need to be directly addressable on the physical network without NAT. Works best on bare metal with a real physical switch. (KVM or Proxmox using a bridged network such as `br0`.)

**ipvlan** — similar to macvlan but all containers share the host's MAC address. Uses IP-level separation instead of MAC-level. Better for environments where the upstream switch limits MAC addresses per port.

For example:

```console
docker network create -d ipvlan \
  --subnet=10.42.20.0/24 \
  --gateway=10.42.0.1 \
  --ip-range=10.42.20.0/24 \
  -o parent=enp1s0 \
  -o ipvlan_mode=l2 \
  ipvlan-net
```

## Troubleshooting

**`Got permission denied` running docker commands:**
```bash
newgrp docker
```
Or log out and back in for the group change to take effect.

**Container name DNS not resolving:**
Confirm both containers are on the same user-defined bridge, not the default `bridge`. Default bridge does not support name resolution.

**`wget: bad address 'webserver'`:**
```bash
docker network inspect labnet | grep -A5 Containers
```
Confirm both `webserver` and `client` are listed.

**Port not accessible from host machine:**
Confirm the firewall port is open and the container is running:
```bash
docker ps
```

> **CentOS Stream 10 — SELinux blocking Docker:**
> ```bash
> sudo setsebool -P container_manage_cgroup 1
> ```