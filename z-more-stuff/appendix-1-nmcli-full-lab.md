# Appendix 1 - NMCLI LAB

## Lab A1-a
**View and analyze the network configuration with nmcli.**

- Basic usage of nmcli.

	Type `nmcli` to see your network configuration. Example results on a Debian client are below. Results on other systems running NetworkManager should be very similar. 

	Example of the `nmcli` command on a Debian client
		
    ```
		enp1s0: connected to Wired connection 1
		"Red Hat Virtio"
		ethernet (virtio_net), 52:54:00:6D:FB:AC, hw, mtu 1500
		ip4 default
		inet4 10.0.2.52/24
		route4 10.0.2.0/24
		route4 0.0.0.0/0
		inet6 fe80::36b4:f533:4478:39c8/64
		route6 fe80::/64

		virbr0: connected to virbr0
		"virbr0"
		bridge, 52:54:00:69:DB:DB, sw, mtu 1500
		inet4 192.168.122.1/24
		route4 192.168.122.0/24

		lo: unmanaged
		"lo"
		loopback (unknown), 00:00:00:00:00:00, sw, mtu 65536

		virbr0-nic: unmanaged
		"virbr0-nic"
		tun, 52:54:00:69:DB:DB, sw, mtu 1500

		DNS configuration:
		servers: 10.0.2.1
		interface: enp1s0

		Use "nmcli device show" to get complete information about known devices and
		"nmcli connection show" to get an overview on active connection profiles.

		Consult nmcli(1) and nmcli-examples(5) manual pages for complete usage details.
    ```

    At the beginning of the results we see "enp1s0: connected to "Wired connection 1". *enp1s0* is the Linux hardware-based name for the network interface. But NetworkManager gives these devices its own names - in this case, *Wired connection 1*. That is the name that we need to use when configuring the network interface with the nmcli command. Lets show how to add and remove static and DHCP-based IP addresses. 

- View the NetworkManager connections

	Type `nmcli connection show`. Here's an example:

	```
	[sysadmin@smauggy ~]$ nmcli connection show
	NAME                UUID                                  TYPE      DEVICE 
	Wired connection 1  58f4b9c3-638d-31e4-bdbf-010a3b56bf47  ethernet  enp3s0 
	EMF-5B              257a1403-e9fd-4a05-bb5c-e91f7baf5274  wifi      wlp2s0 
	virbr0              12a61b1b-f6c6-42a1-b62c-7777cfb94763  bridge    virbr0 
	```

	This example was taken from an actual laptop with wired and wireless connections. Under the "TYPE" column you can see there is an "ethernet" device named *enp3s0*. That is the wired connection, and so NetworkManager calls is "Wired connection 1". Under "TYPE" you will also see a "wifi" device named *wlp2s0*. In this case, NetworkManager refers to it by the name "EMF-5B" (which is actually the name of the wireless network it is connect too - a bit of a security issue, but one which is fixable).

	> Note: You can abbreviate (or truncate) nmcli commands a lot. For example, `nmcli connection show` can be reduced to `nmcli con show`, or just `nmcli c show`. In fact, the "show" portion isn't even necessary. So you could just type `nmcli c` and be done with it! You'll get the same results.

## Lab A1-b

**Working with nmcli in the command line**

- Add an IP address with nmcli. Example:
	
  ```
	nmcli connection modify "Wired connection 1" ipv4.method manual ipv4.address 10.0.2.152/24 ipv4.gateway 10.0.2.1 ipv4.dns 10.0.2.1
	```

	In this example, we specify that the address to be added will be static, then we add the IP address 10.0.2.152/24, and then we add the gateway and DNS IP addresses. You can add multiple IPs if you needed to in this manner, just by comma separating them:
	
  ```
	nmcli connection modify "Wired connection 1" ipv4.method manual ipv4.address 10.0.2.152/24,10.0.2.153/24
	```

	> Note:	You can abbreviate here too, for example: `nmcli con mod` or even `nmcli c m` instead of `nmcli connection modify`. 

		Combine this with tab completion. For example, for the network interface type `"W` and press the tab key. That will auto-complete the name of the interface, which in this case is "Wired connection 1". Combine auto-complete with abbreviations and it can be a real time-saver. Wonderful!

- Down and up the interface

	Once you have made your changes, you need to deactivate and reactivate the network interface for the changes to take effect. This is known as "down" and "up" the interface. To do this type the following two commands:
	`nmcli connection down "Wired connection 1"`
	and
	`nmcli connection up "Wired connection 1"`

	At that point you should see the new IP addresses listed when you run the nmcli command. The following example shows a snippet of the nmcli results. 

	```
	enp1s0: connected to Wired connection 1
	"Red Hat Virtio"
	ethernet (virtio_net), 52:54:00:6D:FB:AC, hw, mtu 1500
	ip4 default
	inet4 10.0.2.152/24
	inet4 10.0.2.153/24
	route4 10.0.2.0/24
	```

	You can see the two IP addresses that were added previously.

- Set the interface to obtain an IP address from a DHCP server.

	Type `nmcli c m "Wired connection 1" ipv4.method auto`

	By selecting "auto" we set the interface to obtain all TCP/IP information from a DHCP server (if one is available) including it's IP address, netmask, gateway address, and DNS server IP address. Down and up the interface for the changes to take effect. You should see something similar to the example snippet below:

	```
	enp1s0: connected to Wired connection 1
	"Red Hat Virtio"
	ethernet (virtio_net), 52:54:00:6D:FB:AC, hw, mtu 1500
	ip4 default
	inet4 10.0.2.152/24
	inet4 10.0.2.153/24
	inet4 10.0.2.139/24
	route4 10.0.2.0/24
	```

	In this case, the system obtained an IP address from a DHCP server on my virtual network. It received the address 10.0.2.139. Now we have two static IP addresses and one dynamic IP address!

- Remove one of the static IP addresses.

	Type `nmcli c m "Wired connection 1" -ipv4.address 10.0.2.153/24` Note the - dash before ipv4, and type in an appropriate IP address based on your configuration. Down and up the interface and you should see the results with the nmcli command. 

## Lab A1-c

**Working with the nmcli interactive shell**

- Access the nmcli shell.

	You can access the nmcli interactive shell for any one of your network interfaces. Once there, you can run multiple commands, and save them all at once. To access the nmcli shell for an interface enter the following:

	`nmcli connection edit "Wired connection 1"`

	Note that it says "edit" this time. That is the option that opens a shell. Remember to change the interface name based on your system. You should see something similar to the following:

	```
	root@deb52:~# nmcli connection edit "Wired connection 1" 

	===| nmcli interactive connection editor |===

	Editing existing '802-3-ethernet' connection: 'Wired connection 1'

	Type 'help' or '?' for available commands.
	Type 'print' to show all the connection properties.
	Type 'describe [<setting>.<prop>]' for detailed property description.

	You may edit the following settings: connection, 802-3-ethernet (ethernet), 802-1x, dcb, sriov, ethtool, match, ipv4, ipv6, tc, proxy
	nmcli> 
	```

	Now, we can enter commands into the shell. 

- Remove the other static IP address. 

	In the shell, type `remove ipv4.address 10.0.2.152/24`. This will remove the static IP address. 

- Set a new static IP address.

	Type `set ipv4.address 10.0.2.52/24`. This will set the original IP address that the system had before. If it asks, type "yes" to set the IP address to manual. 

	!!! note
		You can also abbreviate here. Instead of "remove" type "r", and instead of "set", type "s". Every character counts!

- Save the configuration, activate it, and quit.

	To save the configuration, simply type `save`. Then type `activate` to enable it. Finally, type `quit` to exit out of the shell.  At this point, our IP configuration should be back to what it was when we started Lab 3-7. 

	The beauty of the nmcli shell is that we can do multiple operations like this without having to type "nmcli" every time, or specifying the network interface everytime, because the shell we opened is dedicated to the interface we specified in the beginning. 
!!! note
	For more information about nmcli use the `nmcli -h` and `man nmcli` commands. 

	Also, see the following link:

	https://access.redhat.com/documentation/en-us/red_hat_enterprise_linux/7/html/networking_guide/sec-configuring_ip_networking_with_nmcli

---