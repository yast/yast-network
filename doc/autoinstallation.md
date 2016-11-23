## Introduction

The workflow of the autoinstallation is customized via the [control
file](https://github.com/yast/yast-installation/blob/master/doc/control-file.md) 
like it is in the installation mode but the principal steps are not exactly
the same, and also while in a normal installation the [Second
Stage](https://www.suse.com/documentation/sles-12/singlehtml/book_autoyast/book_autoyast.html#overviewandconcept)
is not needed, in autoinstallation the installation proccess is divided in
two and in the _Second Stage_ is where and when the system configuration is
really done.

There are two ways of give a profile to _AutoYaST_, with (`autoyast` or with
`autoyast2 parameters`), the principal difference from networking point of 
view is that `autoyast` will not fetch the profile which means that doesn't
need the network configuration at all while for `autoyast2` _Linuxrc_ will try
to configure it if needed.

The current steps that involves network configuration are:

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

The network configuration is basically the same that for
[installation](installation.md#Linuxrc), but in case that `autoyast2` is used
then it will fetch and parse the linuxrc options given in the profile and for
that as commented previously will configure the network if needed.


## First Stage

### autoinit

Autoinit will call `iSCSI` or `FCOE` clients if them are enable in _Linuxrc_
and will try to fetch and process the profile.

### autosetup

This client basically will read the `networking` section in the general one,
and also will check if `network` requires manual configuration having an
entry in the 
[semi-automatic](https://www.suse.com/documentation/sles-12/singlehtml/book_autoyast/book_autoyast.html#CreateProfile.Register)
section.

It will write the network configuration only if either `setup_before_proposal`
or `semi-automatic` network configuration has been defined in the profile.

### finish


This client will perform various steps, calling other clients to save the
final configuration which related to networking are:

  - network_finish
  - ssh_settings_finish

## Second Stage
