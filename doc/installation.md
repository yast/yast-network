## Introduction

The workflow of the installation is customized via the [control
file](https://github.com/yast/yast-installation/blob/master/doc/control-file.md), 
and below we have the principal steps concerning network configuration:

  1. Linuxrc
  2. inst_dhcp
  3. inst_lan
  4. manual_configuration
    - SLE (in registration, addons or disks activation)
    - openSUSE (only in addons or disks activation)
  5. finish 
    - network_finish -> save_network

**Note:** If you are interested in knowing more about the installation process check 
[this](https://github.com/yast/yast-installation/blob/master/doc/installation_overview.md) 
documentation.

### Linuxrc 

As the [documentation](https://github.com/openSUSE/linuxrc) of the project 
explains, it is the very early part of the SuSE Installation before YaST runs
which means that it is the first one responsible for the network config.

We can pass many options to the installation process that will be parsed by
linuxrc configuring our interfaces according to that options, or forwarding
the given information through the install.inf file.

By default linuxrc does not configure any interface except in the case that we
specify some special options as for example enabling **vnc**, **ssh** or
with the ifcfg option `ifcfg=*=dhcp`. If any of these options is given, linuxrc
will create a ifcfg file per interface with these options:

```
BOOTPROTO='dhcp'
STARTMODE='auto'
DHCLIENT_SET_HOSTNAME='yes'
```

Or a static config if it is specified so by ifcfg option, for example:

```
ifcfg=eth0=192.168.122.100/24,192.168.122.1,192.168,122.1,suse.de
```

Will create ifcfg-eth0 with:
```
BOOTPROTO='static'
STARTMODE='auto'
IPADDR='192.168.122.100/24'
DHCLIENT_SET_HOSTNAME='yes'
```

ifroute-eth0:
```
default 192.168.122.1 - eth0
```

and network/config:
```
NETCONFIG_DNS_STATIC_SEARCH_LIST="suse.de"
NETCONFIG_DNS_STATIC_SERVERS="192.168.122.1"
```

## inst_dhcp

This client will try to configure dhcp in all the connected cards that haven't 
been configured yet but only in the case that linuxrc has not activated one
previously (i.e. with some parameter that implies a remote connection).

## inst_lan

In case that the network was not configured then the **lan** client will be
launched after the welcome dialog as you can see
[here](https://www.suse.com/documentation/sled-12/singlehtml/book_sle_deployment/book_sle_deployment.html#sec.i.yast2.network)
otherwise the client will be skipped.

## Manual Configuration (lan client)

In some scenarios, special network configuration is needed, i.e:

  - Network storage environment
  - Need of a particular vlan
  - Addons media not available for the configured network.
  - Wrong configuration

For these reasons, there are some places during the installation that allow us
to launch the network configuration client.

  - disks_activate
  - registration (only in SLE)
  - addons

## inst_finish

This step is when the configuration is really copied from the running
system to the installed one. This client calls more specialized clients to
procceed with the configuration, in case of networking it will call
`network_finish` which will call `save_network`.

