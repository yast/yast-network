## Introduction

The workflow of the autoinstallation is customized via the [control
file](https://github.com/yast/yast-installation/blob/master/doc/control-file.md) 
like it is in the installation mode but the principal steps are not exactly
the same, and also while in a normal installation the [Second
Stage](https://www.suse.com/documentation/sles-12/singlehtml/book_autoyast/book_autoyast.html#overviewandconcept)
is not needed, in autoinstallation the installation proccess is divided in
two and in the _Second Stage_ is where and when the system configuration is
really done.

There are two ways to give a profile to _AutoYaST_, with (`autoyast` or with
`autoyast2` parameters), the principal difference is that `autoyast` leaves
the fetching of the profile to YaST wich which means _Linuxrc_ does not need
to configure the network, while for `autoyast` _Linuxrc_ fetches the profile
and may need to configure the network.

The current steps that involve network configuration are:

 - _Linuxrc_
 - First Stage
   - autoinit
   - autosetup
   - finish
      - network_finish
        - save_network
 - Second Stage
   - autoconfigure

## Linuxrc

The network configuration is basically the same as for the
[installation](installation.md#Linuxrc), but in case that `autoyast2` is used
then it will fetch and parse the linuxrc options given in the profile and for
that as commented previously will configure the network if needed.


## First Stage

### autoinit

Autoinit will call `iSCSI` or `FCOE` clients if they are enabled in _Linuxrc_
and will try to fetch and process the profile.

### autosetup

This client basically will read the `networking` section in the `general` one,
and also will check if `network` requires manual configuration having an
entry in the 
[semi-automatic](https://www.suse.com/documentation/sles-12/singlehtml/book_autoyast/book_autoyast.html#CreateProfile.Register)
section.

It will write the network configuration only if either `setup_before_proposal`
or `semi-automatic` network configuration has been defined in the profile.

### finish

This client will perform various steps, calling other clients to save the
final configuration which related to networking area:

  - network_finish
    - save_network

#### network_finish

This client calls `save_network` which copies udev rules and ifcfg files
from the running system which should be the linuxrc config and not the profile
network configuration. 

Take in account that the copying of the ifcfg files will be done only if 
`keep_install_network` has not been set to `false`, being `true` the default
value. More details and examples
[here](https://www.suse.com/documentation/sles-12/singlehtml/book_autoyast/book_autoyast.html#CreateProfile.Network).


In case that we need to use the network configuration declared in the profile
duing the _SecondStage_ then `setup_before_proposal` has to be set to `true`
to configure it  as commented in the [autosetup section](#autosetup). 

The `save_network` method, is also responsible for writing several proposals
like virtualization, dns and network service.

#### ssh_settings_finish

## Second Stage

The _SecondStage_, also known as `continue` in the control file, is basically 
the stage where the configuration should be definitively written.

### autoconfigure

This client will read the [desktop configuration
files](https://yastgithubio.readthedocs.io/en/latest/autoyast-development/#desktop-configuration-file)
of all the installed modules and will parse the section as well will launch
the corresponding client based on what was defined in the file. 

Concerning to networking the most important one is the lan.desktop file which
defines the `networking` profile's resource to be parsed and as it does not
define a specific client to be called it will use the default value `lan_auto`.

And finally `lan_auto` will write our network config.
