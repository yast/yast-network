Network Module Features
-----------------------

Network Services
======================

- wicked
- Network Manager
- no network service
- still support old netconfig ( but no guarantie )

IPv6
==============

- enable/disable it

DHCP Client options
====================

- Set hostname which is send back to the DHCP server
- set machine identifier for asking dhcp
- allow to set specific option for hostname to send for dhcpd client ( how often it is used? )

DNS
===================

- set hostname and domain, combining them into FQDN writting into /etc/hostname
- change hostname with dhcp
- assign hostname to local ip ( so own hostname is always resolvable )
- modify /etc/resolv.conf, keep it manage automatic or modify it manually with selected values

Routing
=========

- allows to assign default gateway for ipv4 and ipv6 and also assign via which device it can be reached
- allows to enable ipv4 and ipv6 forwarding
- allows manual edit of routing table


Devices
=======

- allows to setup it without setup (for bondings and iBFT), dhcp or static ( with ip, hostname, mask )
- manage udev names, allowing renaming of devices when needed
- blinking of device via ethtool for easier device identification
- allows to add additional ips to device
- supported devices: eth, wlan, token ring, infiniband, tun, tap, bridge,vlan, bond, arcnet, bluetooth, dummy, fddi, usb, myrinet (usb and bluetooth looks strange )
- for eth and token ring - allow to specify kernel module needed for device, if it is pcmci or usb and ethtool options
- for each devices it can be specified when activate device, ifplugd priority, firewall zone and MTU
- for bridge it allow to specify any physical devices ( so e.g. tap and tun are filtered out )
- for bonding it allows to specify over which device it bonding
- for wireless it allows to configure mode in which operating, encryption, essid of network and so on
- for infiniband it allows set IPoIB connected x datagram


s390 Devices
============

- allows layer 2 and 3 devices
- support channel ids for devices
- allow layer 2 devices to be in bond
- recognized types - qeth, lcs, ctc, iucv
- allows to set logical link address for layer 2 qeth devices

Firewall parts
==============

- stage1 proposal + write it down ( firewall enable/disable, sshd enable/disable, ssh port open/close, vnc enable/disable)
- assign network device to firewall zone

Network Devices
===============

- ability to check what device is on mount point and if device is network one


Shared Features ( in yast2 )
============================

- Internet test
- Firewall CWM widgets
- Bind9 YaPI interface
- mapping of ports number and its aliases by IANA
- Part ranges support ( well, it looks like object in ycp way )
- firewall part support susefirewall and also firewalld
