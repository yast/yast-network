# Network NG

This document tries to describe the details of the network-ng data model and how all the pieces are
combined.

## Data Model

### Overall Approach

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

### The Configuration Classes

{Y2Network::Config} offers and API to deal with network configuration, but it collaborates with
other classes. These are the most relevant ones:

* {Y2Network::InterfacesCollection}: this class holds a list of interfaces and offers a query API
  (e.g., find all the ethernet interfaces).
* {Y2Network::Interface}: keeps interfaces information. There are one kind of interfaces at this
  point of time: physical and virtual ones.
* {Y2Network::ConnectionConfigsCollection}: this class holds a list of connection configurations
  and offers a query API.
* {Y2Network::ConnectionConfig}: describes a configuration that can be applied to an interface.
  Currently it is bound to an interface name, but we plan to provide more advanced matchers.
* {Y2Network::Routing}: holds routing information, including IP forwarding settings, routing tables, etc.
* {Y2Network::DNS}: holds the DNS configuration, including nameservers, search domains, etc.
* {Y2Network::UdevRule} and {Y2Network::UdevRulePart}: these classes offer and API to handle
  udev rules which are involved in interface renaming and driver assignment.
* {Y2Network::Hwinfo} and {Y2Network::HardwareWrapper}: API to ask for hardware information.

### Multi-Backend Support

As mentioned above, Y2Network is designed to support different backends. It is expected to implement
a reader and a writer for each backend (except for AutoYaST, which is an special case). The reader
will be responsible for checking the system's configuration and building a {Y2Network::Config}
object, containing interfaces, configurations, routes, etc. On the other hand, the writer will be
responsible for updating the system using that configuration object.

As a developer, you rarely will need to access to readers/writers because `Yast::Lan` already offers
an API to read and write the configuration. See the [Accessing the
Configuration](#accessing-the-configuration) section for further details.

#### Sysconfig

The sysconfig backend support is composed by these files:

    src/lib/y2network/sysconfig
    ├── config_reader.rb <- READER
    ├── config_writer.rb <- WRITER
    ├── connection_config_reader.rb
    ├── connection_config_readers
    │   ├── ethernet.rb
    │   ├── wireless.rb
    │   └── ...
    ├── connection_config_writer.rb
    ├── connection_config_writers
    │   ├── ethernet.rb
    │   ├── wireless.rb
    │   └── ...
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

{Y2Network::InterfacesWriter, }{Y2Network::Sysconfig::DNSWriter} and
{Y2Network::Sysconfig::ConnectionConfigWriter}, including smaller classes under
{Y2Network::Sysconfig::ConnectionConfigWriters}, are involved in writing the configuration.

Last but not least, there are additional classes like {Y2Network::Sysconfig::RoutesFile} and
{Y2Network::Sysconfig::InterfaceFile} which abstract the details of reading/writing `ifroute` and
`ifcfg` files.

#### AutoYaST

AutoYaST is a special case in the sense that it reads the information from a profile, instead of
using the running system as reference. Additionally, it does not implement a writer because the
configuration will be written using a different backend (like `sysconfig`).

    src/lib/y2network/autoinst/
    ├── config_reader.rb
    ├── dns_reader.rb
    ├── interfaces_reader.rb
    ├── routing_reader.rb
    ├── type_detector.rb
    └── udev_rules_reader.rb

Another important aspect of the AutoYaST support is that, instead of using a big `Hash`, the
information included in the profile is handled through a set of classes in
{Y2Network::AutoinstProfile} (see {Y2Network::AutoinstProfile::NetworkingSection}). However, there
is some preprocessing that is still done using the original `Hash`.

### Accessing the Configuration

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

## New UI layer

### Interface Configuration Builders

In the old code, there was no clear separation between UI and business logic. In order to improve
the situation, we introduced the concept of [interface configuration
builders](https://github.com/yast/yast-network/blob/network-ng/src/lib/y2network/interface_config_builder.rb).

We already have implemented support for several interface types. You can find them under the
[Y2Network::InterfaceConfigBuilders
namespace](https://github.com/yast/yast-network/tree/843f75bfdb71d4026b3f97facf18eece479b8a0e/src/lib/y2network/interface_config_builders).

### Widgets

The user interaction is driven by a set of sequences, which determines the dialogs are shown to the
user. Each of those dialogs contain a set of widgets, usually grouped in tabs. The content of the
dialog depends on the interface type.

Below you can find some pointers to relevant sequences, dialogs and widgets:

* Sequences:
  *  [Sequences::Interface](https://github.com/yast/yast-network/blob/358bcd13b4e92e7c4e9c0e477c83196ca67b578e/src/lib/y2network/sequences/interface.rb)
* Dialogs:
  * [Dialogs::AddInterface](https://github.com/yast/yast-network/blob/358bcd13b4e92e7c4e9c0e477c83196ca67b578e/src/lib/y2network/dialogs/add_interface.rb)
  * [Dialogs::EditInterface](https://github.com/yast/yast-network/blob/358bcd13b4e92e7c4e9c0e477c83196ca67b578e/src/lib/y2network/dialogs/edit_interface.rb)
* [Y2Network::Widgets](https://github.com/yast/yast-network/tree/358bcd13b4e92e7c4e9c0e477c83196ca67b578e/src/lib/y2network/widgets)
