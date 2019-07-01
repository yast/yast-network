# Test Cases
## Purpose
Goal of this document is to document non trivial testing scenarious we can use to ensure network module is not seriously broken.

## Test Cases

### Complex setup

Test case require VM with two network cards. Setup is:

1. create bonding on top of two cards
2. create bridge on top of bond
3. create two vlans on top of bridge
4. create tun and tap on top bridge
5. create dummy
6. create vlan on top of dummy

#### CLI

For testing this scenario create script that take as params name of two physical devices and using yast2 lan CLI create testing setup.

#### AutoYaST

For testing this scenario create autoyast profile that can be passed to autoinstallation that creates required setup.

#### Runtime

Try to create setup in running system using yast2 lan.

#### Upgrade

Try to upgrade system with this setup using media if everything will work as expected ( setup is not modified and network works in upgrade ).

### S390 setup

Same as Complex setup just without dummy and vlan on top of it.
