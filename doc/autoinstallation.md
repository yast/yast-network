# Networking Configuration During Autoinstallation

## About This Document

Since SUSE Linux Enterprise 12, the manual installation is performed in a single stage. However, the
autoinstallation process is still divided in two different stages (see
https://documentation.suse.com/sles/15-SP1/single-html/SLES-autoyast/#overviewandconcept for further
details).

Thus, **before SLE-15-SP3**, the proper configuration of the network according to the given profile
was done during the *configuration stage*, more commonly known as the *second stage* of the
autoinstallation.

**Since SLE-15-SP3**, the AutoYaST network configuration takes place during the *first stage*, removing
the networking section from the profile so it is not processed during the second stage anymore. 

> **Note**: An option to explicitly force the configuration of the network during the `second stage`
> is expected to be added, but it is still pending.

## Network Configuration Overview

There are two different aspects of the network configuration that we should bear in mind when trying
to understand how AutoYaST sets up the network. The first is *which configuration* is going to be used
and the second is *when it gets applied*.

- Which configuration?
  - Keep the configuration from _Linuxrc_ (`keep_install_network=true`).
  - Use the configuration specified in the profile.
  - Merge both configurations (having a configuration in the profile and `keep_install_network=true`).

- When to apply it?
  - By default, at the end of the 1st stage (when the installation is done)
  - Before the installation/registration takes place (`setup_before_proposal=true`)

### Involved Clients (1st Stage)

The network configuration for the first stage defined in the control file takes part in these
clients:

- **inst_autoinit:** It calls iSCSI or FCOE clients if they are enabled in Linuxrc and tries to
  fetch and process the profile.

- **inst_autosetup:** This client is responsible for importing the networking section from the
  profile when it exists. If `setup_before_proposal` is set to `true` or a `semi-automatic`
  configuration is specified, it also writes the networking configuration at this point and before
  the registration takes place (**FIXME:** online media registration takes place during
  **inst_autoinit**, is will not work).
  
- **save_network:** It is called by the **inst_finish** client and it copies the udev rules and the
  ifcfg files from the running system if needed. Moreover, it is responsible for writing several
  proposals, like virtualization, DNS and network service. Finally, it takes care of writing the
  configuration according to the profile if it was not writting by **inst_autosetup** in advance.

### Fetching the Profile

Depending on the argument used to specify which profile _AutoYaST_ should use, the fetching process is different.

- **autoyast**: YaST fetches the profile, so _Linuxrc_ does not need to set up the network in advance.
- **autoyast2**: Linuxrc is the responsible for fetching the profile so, depending where the profile
  is located, it might need to configure the network.
  
How the profile is fetched is not the only difference between both options, but the differences are
out of the scope of this document.

## Use Cases

### Linuxrc configuration (minimal configuration)

When the network is set up through *Linuxrc*, the configuration is written to the inst-sys and,
depending on the value of the `keep_install_network` element, it can be copied or not to the target
system.

**linuxrc options:** ifcfg=eth0=dhcp autoyast=http://192.1681.122.1/control-files/minimal.xml

  ```xml 
<profile xmlns="http://www.suse.com/1.0/yast2ns" xmlns:config="http://www.suse.com/1.0/configns">
  <general>
    <mode>
      <confirm config:type="boolean">false</confirm>
    </mode>
  </general>
  <software>
    <install_recommended config:type="boolean">true</install_recommended>
    <patterns config:type="list">
      <pattern>Minimal</pattern>
      <pattern>base</pattern>
    </patterns>
  </software>
</profile>
```

> **Note:** By default, the Linuxrc configuration is copied, which means that omitting the
networking section is the same as:

```xml
<networking>
  <keep_install_network config:type=boolean>true</keep_install_network>
</networking>
```

  **Expected Results:**

With this configuration, autosetup does not write anything because there is no networking section,
but as *Linuxrc* network configuration was given, the ifcfg-file exists in the running system.

  ```xml
# cat /etc/sysconfig/network/ifcfg-eth0
BOOTPROTO='dhcp'
STARTMODE='auto'
```

> **Note:** In order to check the configuration written by Linuxrc before the autoinstallation has
> started you can use the pass to linuxrc the startshell=1 option

Therefore, when `save_network` is called by `inst_finish` it copies the udev rules and the sysconfig
network configuration.

About DNS, as no network section is provided, it just writes the configuration proposed by
[NetworkAutoconfiguration](https://github.com/yast/yast-network/blob/a6114782eb8ab2c4864a43a0bcf8f5ed136df53f/src/lib/network/network_autoconfiguration.rb).

### Anticipating the Network Configuration (setup_before_proposal)

There might be some cases where you would need to apply the configuration described in the profile
to be used during the installation. For instance, think of a complex network configuration that
might be hard to set up using _Linuxrc_.

The `setup_before_proposal` element allows to specify that the network must be set up even before
the registration happens.

  **linuxrc options:** `autoyast=usb:///autoinst.xml`

  ```xml
  <networking>
    <setup_before_proposal config:type="boolean">true</setup_before_proposal>
    <interfaces config:type="list">
      <interface>
        <bootproto>static</bootproto>
        <device>eth1</device>
        <ipaddr>192.168.122.100</ipaddr>
        <netmask>255.255.255.0</netmask>
        <network>192.168.122.0</network>
        <prefixlen>24</prefixlen>
        <startmode>auto</startmode>
      </interface>
      <interface>
        <bootproto>dhcp</bootproto>
        <device>eth2</device>
        <startmode>auto</startmode>
      </interface>
    </interfaces>

    <net-udev config:type="list">
      <rule>
        <name>eth1</name>
        <rule>ATTR{address}</rule>
        <value>dc:e4:cc:27:94:c7</value>
      </rule>
      <rule>
        <name>eth2</name>
        <rule>ATTR{address}</rule>
        <value>dc:e4:cc:27:94:c8</value>
      </rule>
    </net-udev>

    <routing>
      <routes config:type="list">
        <route>
          <destination>default</destination>
          <gateway>192.168.122.1</gateway>
          <netmask>-</netmask>
          <device>eth1</device>
        </route>
      </routes>
    </routing>
    <dns>
      <hostname>vikingo-test</hostname>
      <dhcp_hostname config:type="boolean">true</dhcp_hostname>
      <nameservers config:type="list">
        <nameserver>192.168.122.1</nameserver>
      </nameservers>
      <resolv_conf_policy>auto</resolv_conf_policy>
      <searchlist config:type="list">
        <search>suse.com</search>
        <search>localdomain</search>
      </searchlist>
    </dns>
  </networking>
  <host>
    <hosts config:type="list">
      <hosts_entry>
        <host_address>192.168.122.10</host_address>
        <names config:type="list">
          <name>vikingo-test.suse.com vikingo-test</name>
        </names>
      </hosts_entry>
    </hosts>
  </host>
```

### Writing the Configuration at the End

However, in most of the cases, the network configuration will just be written at the end of the
*first stage*, becoming efective once the target system boots. The configuration defined in the
profile is merged with the one defined by _Linuxrc_ unless the `keep_install_network` option is
set to `false`.

**Example:**

**linuxrc options:** `ifcfg=eth0=dhcp autoyast=http://192.1681.122.1/control-files/bonding.xml`

```xml
<?xml version="1.0" encoding="utf-8"?>
  <networking>
    <setup_before_proposal config:type="boolean">false</setup_before_proposal>
    <keep_install_network config:type="boolean">false</keep_install_network>
    <interfaces config:type="list">
      <interface>
        <bonding_master>yes</bonding_master>
        <bonding_module_opts>mode=active-backup miimon=100</bonding_module_opts>
        <bonding_slave0>eth0</bonding_slave0>
        <bonding_slave0>eth1</bonding_slave0>
        <bondoption>mode=balance-rr miimon=100</bondoption>
        <bootproto>static</bootproto>
        <device>bond0</device>
        <ipaddr>192.168.122.61</ipaddr>
        <netmask>255.255.255.0</netmask>
        <network>192.168.122.0</network>
        <prefixlen>24</prefixlen>
        <startmode>auto</startmode>
      </interface>
      <interface>
        <bootproto>none</bootproto>
        <device>eth0</device>
        <startmode>auto</startmode>
      </interface>
      <interface>
        <bootproto>none</bootproto>
        <device>eth1</device>
        <startmode>auto</startmode>
      </interface>
    </interfaces>

    <net-udev config:type="list">
      <rule>
        <name>eth1</name>
        <rule>ATTR{address}</rule>
        <value>dc:e4:cc:27:94:c7</value>
      </rule>
      <rule>
        <name>eth0</name>
        <rule>ATTR{address}</rule>
        <value>dc:e4:cc:27:94:c8</value>
      </rule>
    </net-udev>

    <routing>
      <routes config:type="list">
        <route>
          <destination>default</destination>
          <gateway>192.168.122.1</gateway>
          <netmask>-</netmask>
          <device>bond0</device>
        </route>
      </routes>
    </routing>

    <dns>
      <hostname>vikingo-test</hostname>
      <dhcp_hostname config:type="boolean">true</dhcp_hostname>
      <nameservers config:type="list">
        <nameserver>192.168.122.1</nameserver>
      </nameservers>
      <resolv_conf_policy>auto</resolv_conf_policy>
      <searchlist config:type="list">
        <search>suse.com</search>
        <search>localdomain</search>
      </searchlist>
    </dns>
  </networking>
```
