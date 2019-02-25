## Current Network Code Overview

The main responsabilities of Network configuration resides between yast2-network 
and yast2 (NetworkInterfaces) and them are by sure the more complex parts of
the code.

- NetworkInterfaces (yast2): represent mainly the configured interfaces and is in
  charge of writing the ifcfg-giles. The numbers of bugs in this area are not
  so big, we have been dealing mostly with some normalization of the config or
  better defaults like for wireless configuration.

- LanItems (yast2-network): It was introduced in 2007 [1] for unifying all the
  maps in a single list.

  So basically each LanItems Item has the information about its (hwinfo, ifcfg
  file, [udev rules](udev-rules-implementation.org), and table description 
  (the overview))

  The match between these different objects / hashes is based on the interface 
  or device name, and as we can see it has been one of me most common point of 
  failures in network configuration.

  Of course, naming devices is a known problems in Networking an that was the
  reason of the new predictable network interfaces naming. Something we are
  not prepared yet but which is already used in TW (we still offer to rename
  the interfaces based on [udev rules](udev_rules.md) even when does not work
  on this scenario)


Some of the lacks of the current network configuration module:

1. Callbacks (specially in case of renaming or deleting an interface)

    - Update hosts not only when editing static ip addresses but also when
      removing an interface or changing it to DHCP [2]
    - Update firewalld configuration
    - Update routes

2. Code separation / organization: It is not new and inherit from YCP era, but
   we could start splitting at least the presentation part from the different
   models, and move some responsabilities that currently are part of the
   dialogs to other place. (See for example controllers / actions in
   storage-ng)

3. Duplication of code and bad methods naming, making it difficult to reuse or
   understand if you do not know too deep about it. (It is also described in
   the udev status document) [3]
  
4. Some configuration workflow or interfaces should be revised or redesigned
   as it is not clear enough how to set some of the most common options like
   in wireless config. Not so far hostname setup has been already modified [4].

Note: During the installation, there is not separation between the currenct
configuration and the proposal (except the backend choose). Network is very
fragile and specially when remote installations are in use we do not want to
break current connections (for that maybe having a separation could help, but
this is only an idea that needs to be ellaborated / discussed than a real
problem).

[1] https://lists.opensuse.org/yast-devel/2007-06/msg00001.html
[2] https://trello.com/c/iAKsqifd
[3] https://github.com/yast/yast-network/blob/da0f35221e89f86fd2d998026cb1a0db32379ba8/doc/udev-rules-implementation.org
[4] https://github.com/yast/yast-network/pull/692
