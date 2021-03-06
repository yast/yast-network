## Hostname in Linux ##

We have several hostnames in Linux. Each of them has different usage and different place where to set it up. Some of them can be configured by the YaST's lan module.

## Local system hostname / static hostname (/etc/hostname) ##

You can put a string into /etc/hostname. This string is than used as so called "local system hostname" which is set in the kernel during the boot. In systemd it is named "static hostname". This name is used for identification of your local system. This name is typically used e.g. in logs where individual log entries can be prepended by this name. More importantly this name is not directly related to networking, so putting e.g. FQDN (Fully Qualified Domain Name) here has no sense.

Current static hostname can be displayed by `hostname` command or in systemd world by `hostnamectl --static`

In YaST you can edit this hostname on `Hostname / DNS tab`, `Static Hostname` field. Unlike other ways mentioned above, YaST validates your input. FQDN is allowed here.

![Hostname/DNS tab](pics/hostname_tab.png?raw=true "Hostname/DNS tab")

## Dynamic system hostname(s) (via DHCP) ##

If you want to set hostname via DHCP you have to configure `DHCLIENT_SET_HOSTNAME` option on the client. This option can be configured on global level for all interfaces in `/etc/sysconfig/network/dhcp` file - this setup is then used as global default for all interfaces without that option explicitly configured. You can also configure this option per interface in the interface's ifcfg file. It is very easy to put the system into wrong state here and you will get unpredictable hostname(s) for your system.

If you want to configure `DHCLIENT_SET_HOSTNAME` option via YaST then go to `Hostname / DNS` tab and set desired configuration in "Set Hostname via DHCP" combobox. YaST will configure the global option even the local ones according to user's setup to guarantee safe configuration.

However, we still talk about naming local system here. This name is also called "Transient hostname" in systemd world. You can display it e.g. by `hostnamectl --transient`.

## Static network hostname(s) (/etc/hosts) ##

We're getting off the local system here.

In networking world we are used to access remote computers using human readable names instead of networking addresses (IPs). E.g. we want to use google.com instead of 216.239.36.117 when browsing internet. There are several ways how to achieve this. If you don't want to bother with DNS, you can use local database in /etc/hosts. This file is used as local database translating IP addresses to hostnames - one IP per line.

You can edit this file directly in text editor - you have to take care of correct syntax then, or you can use YaST. This setup is per interface. When using YaST, you have to open statically configured interface and write desired hostname to hostname field beside of static IP configuration fields. YaST also automatically proposes reasonable aliases automatically if you put FQDN there. For example if you use "sle.suse.de" as hostname, the IP will also be assigned with "sle" alias.

![Hostname for interface](pics/hostname_iface.png?raw=true "Hostname for interface")

## Installation proposals ##

YaST tries to configure the local system hostname during installation. Currently (since SLE 15 SP2) YaST configures target system hostname only if it is explicitly set when booting installation with linuxrc's hostname option. In all other cases no hostname is proposed and you have to set the hostname later when booted into installed system.

## Known issues ##

* When you try to delete hostname you can face following issue with runtime hostname.

Empty hostname is treated as invalid by hostname utility and empty /etc/hostname is automatically changed to localhost during the boot.

However, `hostname ''` even `hostname -b --file /etc/hostname` do not work (for empty /etc/hostname). So, runtime remains untouched (hostname command still returns previous hostname).

In opposite `hostnamectl set-hostname ''` works in a sense that it deletes /etc/hostname, erases static hostname and sets transient hostname to localhost, so hostname cmd then correctly shows localhost as result. However, things like bash prompt remains untouched (which is also true when modifying hostname to a nonempty string).

As there currently is no difference between deleting `/etc/hostname` and erasing it, we decided to keep empty `/etc/hostname` to be consistent with state you (can) get right after installation. However, until we switch to hostnamectl reboot is required to `hostname` utility accept empty hostname in some expected way.

* You can see also /etc/HOSTNAME on your system.

This used to be SUSE specific file with different usage than /etc/hostname. However, /etc/HOSTNAME is obsolete and currently is symlinked to /etc/hostname and can disappear in the future completely.

## See also ##

* [man 5 hostname](http://man7.org/linux/man-pages/man5/hostname.5.html) - /etc/hostname file description
* [man 1 hostname](http://man7.org/linux/man-pages/man1/hostname.1.html) - hostname command description
* [man hostnamectl](http://man7.org/linux/man-pages/man1/hostnamectl.1.html)
