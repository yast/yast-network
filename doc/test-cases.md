# Test Cases

This document describes a set of scenarios that are implemented and supported by the module. The
idea is to use them as test cases in order to verify that it is working properly.

## Running System

For this scenarios, you must use the *YaST2 Network* module in an installed system.  It may happen
that your system is using NetworkManager to configure the network. In such a case, as a first step,
you will need to visit the `Global Options` tab and pick `Wicked Service` as `Network Setup Method`.

### DHCP Configuration

1. Pick a network adapter from the `Overview` tab and click `Edit`.
2. Select `Dynamic Address` in the `Address` tab.
3. Save changes.

As a result, the network adapter should get the IP configuration via DHCP. If the interface
looks unconfigured, check the `Device Activation` settings.

### Static Configuration

1. Pick a network adapter from the `Overview` tab and click `Edit`.
2. Introduce IP configuration in `Address` tab.
3. (Optional) Change the firewall zone (or other setting) under the `General` tab.
4. Save changes.

As a result, the network should be configured with the provided IP address. Additionally, you can
check the interfce's zone typing `firewall-cmd --get-zone-of-interface=ethX`, where `ethX` is the
name of the interface.

### Aliasing

1. Pick a network adapter from the `Overview` tab and click `Edit`.
2. Use the table `Additional Addresses` to add a few aliases.
3. Save changes.

As a result, when typing `ip addr`, you should see all IP addresses assigned to that interface.

### Interface Renaming

For renaming scenarios, it would be nice to have an additional adapter that we can reuse
in the next scenario (`Interface Renaming for Removed Devices`).

1. Pick a network adapter from the `Overview` tab and click `Edit`.
2. In the `General` tab, push the `Change` in the `Udev Rules` section.
3. Write the new name and select the attribute to base on.
4. Save changes.

As a result, when typing `ip link`, you should see the new name.

### Interface Renaming for Removed Devices

After setting up the previous scenario, remove now the additional adapter from the machine.
Now you could try to change the name again even if the interface is not present.

1. Pick a network adapter from the `Overview` tab and click `Edit`.
2. In the `General` tab, push the `Change` in the `Udev Rules` section.
3. You should be able to change the name but you will not be able to change the attribute to base
   on.

### Bridge set-up

To set up a bridge, you need to indicate which 

1. Pick a network adapter and set its address configuration as `No Link and IP Setup`.
2. In the `Overview` tab, click `Add` button and select `Bridge` as `Device Type`.
3. Select the network adapter from the first step in the `Bridged Devices` tab.
3. Play around with IP configuration options.

As a result, when typing `ip addr`, you should be able to see a `br0` device (or the name you have
set) with the provided configuration.

### VLAN Configuration

### TUN/TAP Configuration

### Blink

### Change Backend

## Installation

## Upgrade
