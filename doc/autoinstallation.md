Introduction
============

A regular installation of SUSE Linux Enterprise Server 15 SP2 is performed in a single stage. The auto-installation process, however, has been divided in two stages. (see https://documentation.suse.com/sles/15-SP1/single-html/SLES-autoyast/#overviewandconcept for further details)

Thus, the proper configuration of the network according to the given profile was done during the `configuration stage`, more commonly known as the 'second stage' of the auto-installation.

There has been some effort trying to move the network configuration logic to the `first stage` but, that is something that was only partially addressed.

The idea is, that, **since SLE-15-SP3**, the AutoYaST network configuration, by default, will be done during the `first stage`, and the networking section will be removed completely from the profile in order to not call the lan auto  client in the second stage in case of enabled.

First Stage
-----------

The network configuration for the first stage currently defined in the control
file takes part in these clients (**inst_autoinit**, **inst_autosetup** and
**inst_finish**).

- **inst_autoinit:** Autoinit will call iSCSI or FCOE clients if they are
  enabled in Linuxrc and will try to fetch and process the profile.

- **inst_autosetup:** This client is responsible for importing the networking
  section from the profile when it exist, and, in case that the `setup_before_proposal`
  or a `semi-automatic` configuration is specified, it will also write the 
  networking configuration at this point and before the registration takes place.
  (**FIXME:** online media registration is done during autoinit).
  
- **inst_finish:** At the end it will call **save_network** client which copies
  udev rules and ifcfg files from the running system when needed, and which is
  also responsible for writing several proposals like virtualization, dns and
  network service as well as writing the network configuration according to
  the profile when it is not written by **inst_autosetup**.


There are two ways to give a profile to _AutoYaST_, with (`autoyast` or with `autoyast2` parameters), the principal difference is that `autoyast` leaves the fetching of the profile to YaST, which means that _Linuxrc_ does not need to configure the network, while for `autoyast` _Linuxrc_ fetches the profile and may need to configure the network.

Linuxrc configuration (minimal_configuration)
---------------------------------------------

When the network is configured through linuxrc, the network configuration is written to the inst-sys and it can be decided whether the configuration should be copied to the target system or not using the `keep_install_network` option.

### Example:

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

> **Note:** By default, the linuxrc configuration will be keeped, which means that
omitting the section is the same as defining it with that only option.

```xml
<networking>
  <keep_install_network config:type=boolean>true</keep_install_network>
</networking>
```

  **Expected Results:**

  With this configuration autosetup won't write anything because there is no networking section,
  but as linuxrc network configuration was given, the ifcfg-file exists in the running system.

  ```xml
# cat /etc/sysconfig/network/ifcfg-eth0
BOOTPROTO='dhcp'
STARTMODE='auto'
```

> **Note:** In order to check the configuration written by linuxrc before the autoinstallation has started you can use the pass to linuxrc the start_shell=1 option

  Therefore, when `save_network` is called by `inst_finish` it will copy the  udev rules
  and the sysconfig network configuration.

  About DNS, as no network section is provided, it will write the configuration proposed by
  NetworkAutoconfiguration.

Setup before proposal
---------------------

  There are cases where the profile is not fetched from the network and the network 
  configuration is only defined in the profile. 
  
  Specially, when the network configuration is complex with  multiple interfaces involved or when the installation is done in a specific network segment but then the system will be moved to another location or network segment with a different configuration than the used during the installation.

  One of this special cases could require that the network is configured before the registration happens. That can be done with the `setup_before_proposal` option.

### Example:

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

AutoYaST explicit configuration
-------------------------------

However, in most of the cases, the network configuration will just be written at the end of the `first stage` becoming the efective one once the target system is boot. The configuration defined in the profile will be merged with the one defined by linuxrc unless the `keep_install_network` options is false.

**Example:**

**linuxrc options:** `ifcfg=eth0=dhcp autoyast=http://192.1681.122.1/control-files/bonding.xml`

```xml
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

