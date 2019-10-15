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

#### Preparation

Set up four virtualbox VMs. Configure their network device to be connected to the same "Internal Network". Start all four VMs in parallel.

1. In the `Overview` tab, click `Add` button and select `VLAN` as `Device Type`.
2. Choose an appropriate `Real Interface for VLAN` and choose a VLAN ID (!= 0).
3. Assign a statically assigned IP address, e.g. 192.168.100.100/24 and a hostname.
4. Click `Next` and check the `Overview` tab wether it lists a new device named vlan# with the correct Address and parent device.
5. Leave YaST by clicking `OK`. Check the setup by typing `ip -d addr show vlan0` in a terminal window. Check for the vlan id and the correct IP setup.
6. Repeat steps 1.–4. for all the four VMs. Make sure you have two machines each with identical VLAN IDs (step 2.) Make sure you chose IP addresses in the same subnet (192.168.100.###/24) (step 3.).
7. Try cross-pinging form each of the machines to each other. Only the ones using the same VLAN ID should be pingable. The ones using the other VLAN ID cannot ping each other.


### TUN/TAP Configuration

### Blink

To identify an individual network device in a machine with several NICs one can let its link-light blink using YaST. It can only be tested on real hardware.

1. Pick a network adapter from the `Overview` tab and click `Edit`.
2. In the `Hardware` tab, define the duration of blinking and click the `Blink` button.
3. Watch your device's link-LED and check it blinks for the defined number of seconds.

### Change Backend

1. Change `Network Setup Method` in the `Global Options` tab to `Network Services Disabled`
2. Leave YaST by clicking `OK`. Check the setup by typing `ip a` – no configuration should be shown.

1. Change `Network Setup Method` in the `Global Options` tab to `Wicked Service`
3. Pick a network adapter from the `Overview` tab and click `Edit`.
4. Select `Dynamic Address` in the `Address` tab.
5. Save changes.
2. Check the setup by typing `ip a` – some configuration should be shown.

1. Change `Network Setup Method` in the `Global Options` tab to `NetworkManager Service`
2. Leave YaST by clicking `OK`. A warning dialog `Applet needed` should be shown.
3. Check the setup by typing `ip a` – some configuration should be shown.


## Installation

## Upgrade
