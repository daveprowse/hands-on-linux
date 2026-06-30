# LAB 1: NETWORKING COMMANDS & CONFIGURATIONS

In this lab we will cover the following Linux commands:
- ip, ping, traceroute, ss, lsof, nmcli, netcat, nmap, dig, curl, tcpdump

It's important to know your CLI fundamentals when working with Linux. Be sure to practice!

## Lab 1a - System Discovery Commands

In this lab we'll work with the `ip a`, `ip neigh`, and `ping` commands. These allow us to *discover* other systems on the network.

1. In the console (or terminal) type the `ip a` command and view the results. (`ip a` is short for `ip address show`.) Here's an example on a Debian system:

   ```
   root@deb51:~# ip a
   1: lo: <LOOPBACK,UP,LOWER_UP> mtu 65536 qdisc noqueue state UNKNOWN group default qlen 1000
      link/loopback 00:00:00:00:00:00 brd 00:00:00:00:00:00
      inet 127.0.0.1/8 scope host lo
         valid_lft forever preferred_lft forever
      inet6 ::1/128 scope host 
         valid_lft forever preferred_lft forever
   2: enp1s0: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1500 qdisc pfifo_fast state UP group default qlen 1000
      link/ether 52:54:00:f0:2b:b4 brd ff:ff:ff:ff:ff:ff
      inet 10.0.2.51/24 brd 10.0.2.255 scope global enp1s0
         valid_lft forever preferred_lft forever
      inet6 fe80::5054:ff:fef0:2bb4/64 scope link 
         valid_lft forever preferred_lft forever
   3: enp7s0: <BROADCAST,MULTICAST> mtu 1500 qdisc noop state DOWN group default qlen 1000
      link/ether 52:54:00:0a:2a:c9 brd ff:ff:ff:ff:ff:ff
   ```

   This shows two interfaces: 

   1. *lo*, which is the local loopback, something that is found by default on every system that runs TCP/IP. "inet" shows the IPv4 address, which for *lo* is 127.0.0.1.
   2. *enp1s0*, which is the main network interface, used to access other systems and the Internet. The IPv4 address is 10.0.2.51.

   > Note: For help with the ip command type `ip --help`, and for more in-depth information, see the manual page `man ip`.

   > Deep Dive! For an in-depth video and blog post about the ip command, see this link: https://prowse.tech/deep-dive-the-ip-command-in-linux/

2. Now try the `ping` command. This tells us whether or not another system is "alive". For example:

   ```console
   ping localhost -4
   ping 127.0.0.1
   ping ::1
   ping <gateway address>
   ping example.com
   ```

   Analyze the results for each of these queries.

   > Note: `<gateway address>` is whatever your gateway (or router) IP address is. 

   > Note: For help with the ping command type `ping --help`, and for more in-depth information, see the manual page `man ping`. As you can guess, these can be used with just about any command in Linux!

3. Finally, let's work with `ip neigh`. This is short for `ip neighbor` and it will show other systems on the local area network (LAN) that your computer has had recent connectivity with. For example:

   ```console
   ❯ ip neigh
   10.42.0.1 dev enp4s0 lladdr 90:ec:77:98:72:75 REACHABLE 
   192.168.41.1 dev wlo1 lladdr 30:b5:c2:b2:59:e6 REACHABLE 
   10.42.0.11 dev enp4s0 FAILED 
   ```

   You can see that this particular system can connect to other systems on two LANs: 10.42.0.1 and 192.168.41.1. They are considered to be REACHABLE meaning that we have made a recent connection to them (often happens behind the scenes). 

   There is also a connection that FAILED. That is to 10.42.0.11. My system has connected to that in the past, but currently that system is not powered on so we do not get connectivity right now. 

   > Note: You could shorten this command to `ip n` if you wish to! Abbreviate whenever possible!

   Good work! `ip` and `ping` are fundamental analysis commands in Linux.

‼️ **IMPORTANT** - Practice these commands (and all the other commands) often. Practice makes perfect!

## Lab 1b - Path and Routing Discovery

In this portion of the lab we will work with the `ip route`, `traceroute`, and `tracepath` commands. These allow us to discover the route (or path) that is taken between one system and another, but this time, traversing networks. 

1. In the terminal, type the command `ip route`. You should see reuslts similar to the following:

   ```console
   ❯ ip route
   default via 10.42.0.1 dev enp4s0 proto static metric 80 
   10.42.0.0/16 dev enp4s0 proto kernel scope link src 10.42.0.240 metric 80 
   ```

   This shows us several things, most importantly:
   
   - The default gateway for the main connection: 10.42.0.1.
   - The network that we are a part of: 10.42.0.0/16.
   - The metric (in this case 80) which defines which network interface will be accessed first. The lower the number, the higher the priority for networking.

   > Note: You can shorten this command to `ip r`.

   ---   
   **Optional:** 
   
   *We could remove the gateway with the command `ip r delete default` and add one back with, for example: `ip r add default via 10.42.0.1`.* But use with caution!!

2. Try the `traceroute`, `tracepath` and `mtr` commands. For example:

   ```console
   traceroute example.com   
   ```

   ```console
   tracepath example.com   
   ```

   ```console   
   mtr example.com
   ```

   > Note: To get `tracepath` on Debian, install it: `sudo apt install iputils-tracepath`.
   
   > To get `mtr` on Debian, install it with either: `sudo apt install mtr-tiny` (preferred terminal version) or `sudo apt install mtr` (GUI version). 

   Each of these shows the path to a final destination, measured in hops. Each hop is essentially another router (or network) that your connection is crossing. `mtr` gives the added benefit of running in a separate continuous shell and combines tracing and pinging together. 
   
   `tracepath` and `mtr` are modern alternatives to `traceroute`. If you don't have `traceroute` on your system by default, this is why! 

## Lab 1c - Port and Socket Discovery

Now let's work with ports and sockets. First, let's describe them.

- **Port**: A 16-bit number (0–65535) that identifies a specific service or process on a host. Ports don't exist as physical things per se — they're a logical addressing mechanism used by TCP/UDP to route traffic to the correct application (e.g. port 22 for SSH, port 443 for HTTPS).
  - OSI: Ports live on OSI Layer 4 - Transport, as source and destination numbers.
- **Socket**: The actual endpoint of a network connection. A socket is the combination of an IP address, a port number, and the Transport layer protocol (TCP or UDP) — e.g. 192.168.1.42:22/tcp.    
  - OSI: Sockets live in the Linux Kernel *and* in Userspace as a sort of boundary between Layers 4 and 5. The IP address is provided by Layer 3, and the port is provided by Layer 4. These are exposed to Layer 7 application protocols via the kernel's socket API. 
  > Note: In Linux, a socket is also a file descriptor the kernel uses to track that specific connection. But we are not covering that in this course.

Now let's use them:

**Step 1 — List all *listening* TCP sockets**
 
```console
ss -tln
```
 
`-t` TCP, `-l` listening only, `-n` numeric (no DNS lookups) .
 
**Step 2 — List all *established* connections**
 
```console
ss -tn
```

Add `-p` to show processes.

> Note: Another set of flags I use often is `ss -tanpu`. This combines listening sockets (`-l`) and established sockets (`-t`) for UDP and TCP (`-u`) and shows the owning process (`-p`). To see *everything* simply use the `ss` command but be prepared for a lot of output! 

**Step 3 - List connections with `lsof`**

```console
sudo lsof -i
```

**Step 4 — Find which process owns a specific port**
 
```console
sudo lsof -i :22
```
 
Replace `22` with any port you want to inspect.
 
## Lab 1d - Using nmcli to configure IP

**View and analyze the network configuration with nmcli.**

Type `nmcli` to see your network configuration. Example results on a Debian client are below. Results on other systems running NetworkManager should be very similar. 

Example of the `nmcli` command on a Debian client:
		
```console
   dave@deb1:~$ nmcli
   enp1s0: connected to Wired connection 1
   "Red Hat Virtio 1.0"
   ethernet (virtio_net), 52:54:00:4C:A5:3E, hw, mtu 1500
   ip4 default
   inet4 10.0.2.51/24
   route4 default via 10.0.2.1 metric 100
   route4 10.0.2.0/24 metric 100
   inet6 fe80::5054:ff:fe4c:a53e/64
   route6 fe80::/64 metric 1024

   lo: connected (externally) to lo
   "lo"
   loopback (unknown), 00:00:00:00:00:00, sw, mtu 65536
   inet4 127.0.0.1/8
   inet6 ::1/128

   DNS configuration:
   servers: 10.0.2.1
   interface: enp1s0

```

At the beginning of the results we see "enp1s0: connected to "Wired connection 1". *enp1s0* is the Linux hardware-based name for the network interface. But NetworkManager gives these devices its own names - in this case, *Wired connection 1*. That is the name that we need to use when configuring the network interface with the nmcli command. Lets show how to add and remove static and DHCP-based IP addresses. 

**Working with nmcli in the command line**

- Add an IP address with nmcli. Example:
	
   ```
   nmcli connection modify "Wired connection 1" ipv4.method manual ipv4.address 10.0.2.152/24 ipv4.gateway 10.0.2.1 ipv4.dns 10.0.2.1
   ```

   In this example, we specify that the address to be added will be static, then we add the IP address 10.0.2.152/24, and then we add the gateway and DNS IP addresses. 

   > Note:	You can abbreviate here too, for example: `nmcli con mod` or even `nmcli c m` instead of `nmcli connection modify`. 

   > Combine this with tab completion. For example, for the network interface type `"W` and press the tab key. That will auto-complete the name of the interface, which in this case is "Wired connection 1". Combine auto-complete with abbreviations and it can be a real time-saver. Wonderful!

- Down and up the interface

	Once you have made your changes, you need to deactivate and reactivate the network interface for the changes to take effect. This is known as "down" and "up" the interface. To do this type the following two commands:
	`nmcli connection down "Wired connection 1"`
	and
	`nmcli connection up "Wired connection 1"`

	At that point you should see the new IP address listed when you run the `nmcli` command. 

- Remove the static IP address

	Type `nmcli c m "Wired connection 1" -ipv4.address 10.0.2.152/24` Note the dash (`-`) before ipv4, and type in an appropriate IP address based on your configuration. Down and up the interface and you should see the results with the nmcli command. 

> Note: This is just the tip of the iceberg when it comes to `nmcli`. Check out the help file and manual page for the command to learn more. Also, see [Appendix Lab 1](../z-more-stuff/appendix-1-nmcli-full-lab.md) for a more in-depth `nmcli` lab. 

## Lab 1e - Network Scanning and Remote Discovery 



(nmap, netcat, arping)    


---

## Additional Information

Check out the links for more information about some of the topics we covered in this lab.

### TCP/IP Reference Links

- TCP/IP Guide (2005): <https://learning.oreilly.com/library/view/tcpip-guide/9781593270476/>
- TCP/IP Illustrated (2011): <https://learning.oreilly.com/library/view/tcpip-illustrated-volume/9780132808200/>
- Computer Networks & Internets (Douglas Comer) - if you can get your hands on one...

### OSI Reference Model links

https://en.wikipedia.org/wiki/OSI_model

https://www.youtube.com/watch?v=m_RfrAfUFx8

The Open Systems Interconnection (OSI) reference model is used to define how data is transmitted and received between systems. It defines how protocols work, and how programs will use those protocols. It is made up of seven layers, listed from layer 7 down to layer 1 below:

- Layer 7:  Application
- Layer 6:  Presentation
- Layer 5:  Session
- Layer 4:  Transport
- Layer 3:  Network
- Layer 2:  Data Link
- Layer 1:  Physical

Different protocols work on different layers. For example, in Lab 1-1 we used the `ip a` command. This displayed the IP address of the system (10.0.2.51). IP addresses exist on layer 3 of the OSI model: the network layer. Other protocols work on other layers. For instance, TCP works on layer 4 (transport), and HTTP works on layer 7 (application). When you have different protocols working on different layers, they are considered to be *stacked* upon each other. This leads to terms such as "OSI stack", "TCP/IP stack", or simply "network stack". The OSI model can be very helpful when designing programs, designing networks, and troubleshooting network connections, as well as doing packet analysis. 

 
There are no other labs in this section. See the reference links below for more information about TCP/IP and the OSI model.

---

---
