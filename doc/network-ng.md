# Network NG

This document tries to describe the details of the network-ng data model and how all the pieces are
combined.

## Overall Approach

{Y2Network::Config} and other associated classes represent the network configuration in a backend
agnostic way. It should not matter whether you are using `sysconfig` files, NetworkManager or
networkd.

The systems' configuration is read using *configuration readers*, which are special classes which
implements the logic to find out the details and build a proper {Y2Network::Config} object. Once the
wanted modifications are performed to this configuration object, it could be written in the
filesystem by using a *configuration writer*.

                 +--------+             +---------+
    reader ----> | config | -- user --> | config' |----> writer
      ^          +--------+             +---------+        |
      |                                                    |
      |                     +--------+                     |
      +---------------------| system |<--------------------+
                            +--------+

Obviously, we should implement configuration readers and writers for whathever backend we would like
to support. At this point of time, only `Sysconfig` and `Autoinst` are supported.

## The Configuration Classes

{Y2Network::Config} offers and API to deal with network configuration, but it collaborates with
other classes.

* {Y2Network::InterfacesCollection}: this class holds a list of interfaces and offers a query API
  (e.g., find all the ethernet interfaces).
* {Y2Network::Interface}: keeps interfaces information. There are three kind of interfaces at this
  point of time: physical, virtual and fake (physical but not present) ones.
* {Y2Network::ConnectionConfig}: describes a configuration that can be applied to an interface.
  Currently it is bound to an interface name, but we plan to provide more advanced matchers.
* {Y2Network::Routing}: holds routing information, including IP forwarding settings, routing tables, etc.

## Backend Support

As mentioned above, Y2Network is designed to support different backends. It is expected to implement
a reader and a writer for each backend (except for AutoYaST, which is an special case). The reader
will be responsible for checking the system's configuration and building a {Y2Network::Config}
object, containing interfaces, configurations, routes, etc. On the other hand, the writer will be
responsible for updating the system using that configuration object.

As a developer, you rarely will need to access to readers/writers because `Yast::Lan` already offers
an API to read and write the configuration. See the [Accessing the
Configuration](#accessing-the-configuration) section for further details.

### Sysconfig

The sysconfig backend support is composed by these files:

    src/lib/y2network/sysconfig
    ├── config_reader.rb <- READER
    ├── config_writer.rb <- WRITER
    ├── connection_config_reader.rb
    ├── connection_config_readers
    │   ├── eth.rb
    │   └── wlan.rb
    ├── connection_config_writer.rb
    ├── connection_config_writers
    │   ├── eth.rb
    │   └── wlan.rb
    ├── dns_reader.rb
    ├── dns_writer.rb
    ├── interface_file.rb
    ├── interfaces_reader.rb
    └── routes_file.rb

{Y2Network::Sysconfig::ConfigReader} and {Y2Network::Sysconfig::ConfigWriter} are the reader and
writer classes. Each of them cooperates with a set of ancillary classes in order to get the job
done.

{Y2Network::Sysconfig::DNSReader}, {Y2Network::Sysconfig::InterfacesReader} and
{Y2Network::Sysconfig::ConnectionConfigReader} are involved in reading the configuration. The logic
to read the configuration for a connection (e.g., `ifcfg-eth0`, `ifcfg-wlan0`, etc.) is implemented
in a set of smaller classes (one for each time of connection) under
{Y2Network::Sysconfig::ConnectionConfigReaders}.

{Y2Network::Sysconfig::DNSWriter} and {Y2Network::Sysconfig::ConnectionConfigWriter}, including
smaller classes under {Y2Network::Sysconfig::ConnectionConfigWriters}, are involved in writing the
configuration. In this case, it does not exist a `InterfacesWriter` class, because when it comes to
interfaces the configuration is handled through connection configuration files.

Last but not least, there are additional classes like {Y2Network::Sysconfig::RoutesFile} and
{Y2Network::Sysconfig::InterfaceFile} which abstract the details of reading/writing `ifcfg` files.

### AutoYaST

AutoYaST is a special case in the sense that it reads the information from a profile, instead of
using the running system as reference. Additionally, it does not implement a writer because the
configuration will be written using a different backend (like sysconfig).

    src/lib/y2network/autoinst/
    ├── config_reader.rb
    ├── dns_reader.rb
    └── routing_reader.rb

For the time being, it only implements support to read DNS and routing information.

## Accessing the Configuration

The `Yast::Lan` module is still the entry point to read and write the network configuration.
Basically, it keeps two configuration objects, one for the running system and another want for the
wanted configuration.

    Yast.import "Lan"
    Yast::Lan.read(:cache)
    system_config = Yast::Lan.system_config
    yast_config = Yast::Lan.yast_config
    system_config == yast_config # => true
    # let's change IP forwarding settings
    yast_config.routing.forward_ipv4 = !system_config.routing.forward_ipv4
    system_config == yast_config # => false
    # write the new configuration
    Yast::Lan.Write

Any change you want to apply to the running system should be performed by modifying the
`yast_config` and writing the changes.

## AutoYaST Support

AutoYaST is somehow and special case, as the configuration is read from the profile instead of the
running system. So in this scenario, YaST2 Network will read the configuration using the `Autoinst`
reader and will write it to the final system using the one corresponding to the wanted backend.

## Current Status

### Reading/Writing Interfaces

| Interface type  | read | write |
|-----------------|------|-------|
| Ethernet        |  ✓  |   ✓   |
| Wireless        |  ✓  |   ✓   |
| InfiniBand      |  ⌛   |       |
| Bridge          |  ⌛   |       |
| Bonding         |      |       |
| VLAN            |      |       |
| TAP             |      |       |
| TUN             |      |       |
| USB             |      |       |
| Dummy           |      |       |
| s390 types      |      |       |
