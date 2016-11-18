Network Module Features
-----------------------

Network Services
======================

- wicked
- Network Manager
- no network service

IPv6
==============

- enable/disable it

DHCP Client options
====================

- set hostname according to dhcp response
- set machine identifier for asking dhcp
- allow to set specific option for hostname to send for dhcpd client ( how often it is used? )

DNS
===================

- set hostname
- set domain
- change hostname with dhcp ( looks same as in dhcp client options )
- assign hostname to local ip ( so own hostname is always resolvable )
- modify /etc/resolv.conf, keep it manage automatic or modify it manually with selected values

Routing
=========

- allows to assign gateway for ipv4 and ipv6 and also assign via which device it can be reached
- allows to enable ipv4 and ipv6 forwarding
- allows manual edit of routing table


Devices
=======

- allows to setup it without setup (for bondings), dhcp or static ( with ip, hostname, mask )
- allows to add additional ips to device
- supported devices: eth, wlan, token ring
- for eth and token ring - allow to specify kernel module needed for device, if it is pcmci or usb and ethtool options

