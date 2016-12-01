Network Module Features
=======================

Network Services
----------------

- wicked
- Network Manager
- no network service
- still support old netconfig ( but no guarantee )

IPv6
----

- enable/disable it

DHCP Client Options
-------------------

- Set hostname which is sent back to the DHCP server
- set machine identifier for asking DHCP
- allow to set specific option for hostname to send for dhcpd client ( how often it is used? )

DNS
---

- set hostname and domain, combining them into FQDN writing into /etc/hostname
- change hostname with dhcp
- assign hostname to local IP ( so own hostname is always resolvable )
- modify /etc/resolv.conf, have it managed automatically or modify it manually with selected values

Routing
-------

- allow to assign default gateway for IPv4 and IPv6 and also assign via which device it can be reached
- allow to enable IPv4 and IPv6 forwarding
- allow manual editing of routing table


Devices
-------

- allow to use no setup (for bondings and iBFT), DHCP or static ( with IP, hostname, mask )
- manage udev names, allowing renaming of devices when needed
- blinking of device via `ethtool` for easier device identification
- allow to add additional IPs to device
- supported devices: eth, wlan, token ring, infiniband, tun, tap, bridge,vlan, bond, arcnet, bluetooth, dummy, fddi, usb, myrinet (usb and bluetooth looks strange )
- for eth and token ring - allow to specify kernel module needed for device, if it is pcmci or usb and ethtool options
- for each device it can be specified when to activate it, ifplugd priority, firewall zone, and MTU
- for bridge it allows to specify any physical devices ( so e.g. tap and tun are filtered out )
- for bonding it allows to specify over which device it is bonding
- for wireless it allows to configure mode of operation, encryption, essid of network and so on
- for infiniband it allows to set IPoIB connected x datagram


s390 Devices
------------

- allow layer 2 and 3 devices
- support channel IDs for devices
- allow layer 2 devices to be bonded
- recognized types - qeth, lcs, ctc, iucv
- allow to set logical link address for layer 2 qeth devices

Firewall Parts
--------------

- stage1 proposal + write it down ( firewall enable/disable, sshd enable/disable, ssh port open/close, vnc enable/disable)
- assign network device to firewall zone

Network Storage Devices
-----------------------

- ability to check what device is on mount point and if device is network one


Shared Features ( in yast2 )
----------------------------

- Internet test
- Firewall CWM widgets
- Bind9 YaPI interface
- mapping of port numbers and their aliases by IANA
- port ranges support ( well, it looks like object in ycp way )
- firewall part support susefirewall and also firewalld
