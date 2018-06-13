Udev Rules in yast-network
==========================

What are Udev Rules
-------------------

If a computer has two network cards, how does it determine which one is
*eth0* and which one is *eth1*?

[Udev][udev] is a **u**serspace **dev**ice manager for the Linux kernel.
One of its responsibilities is *naming* the devices.
Udev uses an extensive set of *udev rules* to direct its configuration and
naming of the devices. Most of the rules (in /lib) are part of subsystem
packages, like NetworkManager or device-mapper, and some (in /etc) are
maintained by the administrator, and that's where YaST helps.

[udev]: https://en.wikipedia.org/wiki/Udev

For example, here are rules to name eth0 and eth1 based on their PCI bus
positions, 0000:00:03.0 and 0000:00:07.0:

```
SUBSYSTEM=="net", ACTION=="add", DRIVERS=="?*", ATTR{type}=="1", ATTR{dev_port}=="0", \
    KERNELS=="0000:00:03.0", NAME="eth0"
SUBSYSTEM=="net", ACTION=="add", DRIVERS=="?*", ATTR{type}=="1", ATTR{dev_port}=="0", \
    KERNELS=="0000:00:07.0", NAME="eth1"
```

### Network as Compared to Storage

"Udev" is mentioned a lot in yast-storage-ng, but the situation is quite
different:

What network and storage devices have in common is that both kinds of devices
have a *bus position*, and some kind of *unique id*, and a *short kernel
name*.

Storage devices have a device file that exists in the filesystem, so naturally
you can make symlinks pointing to `/dev/sda1` from
`/dev/disk/by-path/pci-0000:00:1f.2-scsi-0:0:0:0-part1` or from
`/dev/disk/by-id/ata-ST3500418AS_9VMN8X8L-part1`. For which there are udev
rules that simply *work* and YaST does not have to care.

Networking devices **suck** because they **do not exist** in the filesystem*,
so we cannot have multiple symlinks to a "canonical" device name. We must
embed the paths and ids in the udev rules, even to choose one of the naming
schemes over the others (name NICs by MAC, not by PCI bus position).

\* Well, there are `/sys/class/net/*` but the networking programs do not use
them.

### TODO more intro

For a NIC a widget exists where you can change its name and choose
whether it will be pinned to its MAC (Ethernet address), or its PCI bus
address.

Why
---

The code of yast-network is messy, so Udev Rules is one area to clean it
up. It is simple enough and well defined.

Requirements
------------

### Persistent Name Rules


#### set the name of a network interface

NIC > Edit > Hardware > Udev Rules > Device Name > Change >
  Device Name

(But if a name is changeable, what then identifies an interface?
Between reboots it is the interface index.)

#### switch the primary key for interface naming

NIC > Edit > Hardware > Udev Rules > Device Name > Change >
  Base Udev Rule on: BusID (bus position) or MAC address

#### set the names of multiple network interfaces

This happens during AY setup.

This needs to deal with the situation where you have eth0+eth1 and want to
name them eth1+eth0, while avoiding an intermediate eth1+eth1 situation.

#### AutoYaST Profile Import and Export ####

```xml
<networking>
  <net-udev config:type="list">
    <rule>
      <name>eth0</name>
      <rule>ATTR{address}</rule>
      <value>00:30:6E:08:FF:80</value>
    </rule>
  </net-udev>
</networking>
```

Semantics: the device **name** is identified by the field with the key
**rule** (sic!) having the value **value** (that does not allow some
complex identifications).

The rnc schema says all elements are optional but the [SLE 12 docs][sle12ay]
(also SLE 15) says name+rule+value are all required.

[sle12ay]: https://www.suse.com/documentation/sles-12/singlehtml/book_autoyast/book_autoyast.html#CreateProfile.Network.names

### Device Driver Rules

The UI has a widget for changing the driver of a NIC:

NIC > Edit > Hardware > Kernel Module > Module Name + Options

Areas NOT in scope
------------------

These are related to Udev in the current code but let's not touch them
in this 1st stage.

### s390 rules (AY: networking/s390-devices)

are similar but not really

-   set up a virtual device
-   do not include a name(!?)


API
---

### Y2Network::NameRule

Ensures that one NIC keeps the name assigned to it
(using a {::UdevRule udev rule})

- @udev [UdevRule]
- attr_accessor matcher (:bus_id or :mac)
- attr_accessor match_value [String]
  eg. "11:22:33:aa:bb:cc" or "0000:00:03.0"
- attr_accessor name [String]
udev["NAME"]

- .from_ay(Hash{"name", "rule", "value"})
- #to_ay[Hash{"name", "rule", "value"}]

### Y2Network::NameRules

Is this just an array of NameRule ?
Mostly, but importantly it deals with their persistence

- #pathname
"/etc/udev/rules.d/70-persistent-net.rules"

- .from_ay(Array<Hash{"name", "rule", "value"}>)
- #to_ay [Array<Hash{"name", "rule", "value"}>]


### ::UdevRule
