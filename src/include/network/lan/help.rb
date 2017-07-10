# encoding: utf-8

# ***************************************************************************
#
# Copyright (c) 2012 Novell, Inc.
# All Rights Reserved.
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of version 2 of the GNU General Public License as
# published by the Free Software Foundation.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.   See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, contact Novell, Inc.
#
# To contact Novell about this file by physical or electronic mail,
# you may find current contact information at www.novell.com
#
# **************************************************************************
module Yast
  module NetworkLanHelpInclude
    def initialize_network_lan_help(_include_target)
      textdomain "network"

      @help = {
        "read"              => # Network cards read dialog help 1/2
                               _(
                                 "<p><b><big>Initializing Network Card\nConfiguration</big></b><br>Please wait...<br></p>\n"
                               ) +
                                 # Network cards read dialog help 2/2
                                 _(
                                   "<p><b><big>Aborting the Initialization:</big></b><br>\nSafely abort the configuration utility by pressing <B>Abort</B> now.</p>\n"
                                 ),
        "write"             => # Network cards write dialog help 1/2
                               _(
                                 "<p><b><big>Saving Network Card\nConfiguration</big></b><br>Please wait...<br></p>\n"
                               ) +
                                 # Network cards write dialog help 2/2
                                 _(
                                   "<p><b><big>Aborting Saving:</big></b><br>\nAbort saving by pressing <b>Abort</b>.</p>\n"
                                 ),
        "managed"           => # Network setup method help
                               # NetworkManager and wicked are programs
                               _(
                                 "<p><b><big>Network Setup Method</big></b></p>\n" \
                                   "<p>Use the <b>NetworkManager</b> as a desktop applet\n" \
                                   "managing connections for all interfaces. It is well suited\n" \
                                   "for switching among wired and wireless networks.</p>\n"
                               ) +
                                 _(
                                   "<p>Use <b>wicked</b> if you do not run a desktop environment\n" \
                                     "or need to use multiple interfaces at the same time.</p>\n"
                                 ) +
                                 # For systems not including NetworkManager by default (bnc#892678)
                                 _(
                                   "<p><b>NetworkManager</b> is not part of every base\n" \
                                   "installation repository. For example, to enable it on SUSE\n" \
                                   "Linux Enterprise Server add the Workstation Extension\n" \
                                   "repository and install the 'NetworkManager' package.</p>\n"
                                 ),
        "overview"          =>
                               _(
                                 "<p><b><big>Network Card Overview</big></b><br>\n" \
                                 "Obtain an overview of installed network cards. Additionally,\n" \
                                 "edit their configuration.<br></p>\n"
                               ) +
                                 _(
                                   "<p><b><big>Adding a Network Card:</big></b><br>\nPress <b>Add</b> to configure a new network card manually.</p>\n"
                                 ) +
                                 _(
                                   "<p><b><big>Configuring or Deleting:</big></b><br>\n" \
                                   "Choose a network card to change or remove.\n" \
                                   "Then press <b>Edit</b> or <b>Delete</b> respectively.</p>\n"
                                 ),
        "ipv6"              =>
                               # IPv6 help
                               _(
                                 "<p><b><big>IPv6 Protocol Settings</big></b></p>\n" \
                                   "<p>Check <b>Enable IPv6</b> to enable the ipv6 module in the kernel.\n" \
                                   "It is possible to use IPv6 together with IPv4. This is the default option.\n" \
                                   "To disable IPv6, uncheck this option. This will blacklist the kernel \n" \
                                   "module for ipv6. If the IPv6 protocol is not used on your network, the response \n" \
                                   "time can be faster.</p>\n"
                               ) +
                                 _("<p>All changes will be applied after reboot.</p>"),
        "routing"           =>
                               # Routing dialog help 1/2
                               _(
                                 "<p>The routing can be set up in this dialog.\n" \
                                   "The <b>Default Gateway</b> matches every possible destination, but poorly. \n" \
                                   "If any other entry exists that matches the required address, it is\n" \
                                   "used instead of the default route. The idea of the default route is simply\n" \
                                   "to enable you to say \"and everything else should go here.\"</p>\n"
                               ) +
                                 _(
                                   "<p>For each route, enter destination network IP address, gateway address,\n" \
                                     "and netmask. You can use either IPv4 netmask or prefix length when defining\n" \
                                     "network part of route. Prefix length has to be prefixed using '/'.\n" \
                                     "To omit any of these values, use a dash sign \"-\". Select\n" \
                                     "the device through which the traffic to the defined network will be routed.\"-\" is an alias for any interface.\n" \
                                     "Please note that in case of IPv6 networks only prefix length is accepted\n" \
                                     "for netmask definition.</p>\n"
                                 ) +
                                 # Routing dialog help 2/2
                                 _(
                                   "<p>Enable <b>IPv4 Forwarding</b> (forwarding packets from external networks\n" \
                                     "to the internal one) if this system is a router.\n"
                                 ) +
                                 _(
                                   "<p>Enable <b>IPv6 Forwarding</b> (forwarding packets from external networks\n" \
                                     "to the internal one) if this system is a router.\n" \
                                   "<b>Warning:</b> IPv6 forwarding disables IPv6 stateless address\n" \
                                   "autoconfiguration (SLAAC)."
                                 ) +
                                 _(
                                   "<p><b>Important:</b> if the firewall is enabled, allowing forwarding alone is not enough. \n" \
                                   "You should enable masquerading and/or set at least one redirect rule in the\n" \
                                   "firewall configuration. Use the YaST firewall module.</p>\n"
                                 ),
        "dhcp_hostname"     =>
                               _(
                                 "<p>If you are using DHCP to get an IP address, check whether you get\n" \
                                 "also a hostname via DHCP. The hostname will be set automatically by the DHCP client.\n" \
                                 "However, changing the hostname at runtime may confuse the graphical desktop. \n" \
                                 "Therefore, set this option to \"no\" if you connect to different networks that assign \n" \
                                 "different hostnames. Otherwise you can specify a particular interface to use or use a generic \"any\" \n" \
                                 "option. However this option can lead to strange behavior if you have a multihomed system \n" \
                                 "connected to more DHCP networks.</p>\n" \
                               ),
        "write_hostname"    =>
                               _(
                                 "<p><b>Assign Hostname to Loopback IP</b> associates your hostname with \n" \
                                 "the IP address <tt>127.0.0.2</tt> (loopback) in <tt>/etc/hosts</tt>. This is a \n" \
                                 "useful option if you want to have the hostname resolvable at all times, even \n" \
                                 "without an active network. In all other cases, use it carefully, especially \n" \
                                 "if this computer provides some network services.</p>\n"
                               ),
        "searchlist_s"      =>
                               _(
                                 "<p>Enter the name servers and domain search list for resolving \nhostnames. Usually they can be obtained by DHCP.</p>\n"
                               ) +
                                 # resolver dialog help
                                 _(
                                   "<p>A name server is a computer that translates hostnames into\n" \
                                   "IP addresses. This value must be entered as an <b>IP address</b>\n" \
                                   "(for example, 192.168.0.42), not as a hostname.</p>\n"
                                 ) +
                                 # resolver dialog help
                                 _(
                                   "<p>Search domain is the domain name where hostname searching starts.\n" \
                                   "The primary search domain is usually the same as the domain name of\n" \
                                   "your computer (for example, suse.de). There may be additional search domains\n" \
                                   "(such as suse.com). Separate the domains with commas or white space.</p>\n"
                                 ),
        "hostname_global"   =>
                               _(
                                 "<p>Enter the short name for this computer (e.g. <i>mymachine</i>) and the DNS domain\n" \
                                 "(e.g. <i>example.com</i>) that it belongs to. The domain is especially important if this \n" \
                                 "computer is a mail server. You can view the hostname of you computer using the <i>hostname</i> \n" \
                                 "command.</p>"
                               ),
        "dns_config_policy" =>
                               _(
                                 "<p>Select the way how the DNS configuration will be modified (name servers,\n" \
                                 "search list, the content of <i>/etc/resolv.conf</i>). Normally, it is handled\n" \
                                 "by the <i>netconfig</i> script, which merges statically defined data with\n" \
                                 "dynamically obtained data (e.g. from the DHCP client, NetworkManager,\n" \
                                 "etc.). This is the default. <b>Use Default Policy</b> is sufficient for most\n" \
                                 "configurations.</p>\n"
                               ) +
                                 _(
                                   "<p>By choosing <b>Only Manually</b>, <i>netconfig</i> will no longer be\n" \
                                   "allowed to modify <i>/etc/resolv.conf</i>. You can however edit the file\n" \
                                   "manually. By choosing <b>Use Custom Policy</b>, you may specify a custom\n" \
                                   "policy string, which consists of a comma-separated list of interface names,\n" \
                                   "including wildcards, with STATIC and STATIC_FALLBACK as predefined special\n" \
                                   "values. For more information, see the <i>netconfig</i> manual page. Note:\n" \
                                   "Leaving the field blank is the same as using the <b> Only Manually</b>\n" \
                                   "policy.</p>\n"
                                 ),
        "bootproto"         => # Address dialog help 1-6/8: dynamic address preferred
                               # Address dialog help 1/8
                               _(
                                 "<p><b><big>Address Setup</big></b></p>\n" \
                                   "<p>Select <b>No Address Setup</b> if you do not want to assign an IP address to this device.\n" \
                                   "This is particularly useful for bonding ethernet devices.</p>\n"
                               ) +
                                 _(
                                   "<p>Check <b>iBFT</b> if you want to keep the network configured in your BIOS.</p>\n"
                                 ) +
                                 # Address dialog help 2/8
                                 _(
                                   "<p>Select <b>Dynamic Address</b> if you do not have a static IP address \nassigned by the system administrator or your Internet provider.</p>\n"
                                 ) +
                                 # Address dialog help 3/8
                                 _(
                                   "<p>Choose one of the dynamic address assignment methods. Select <b>DHCP</b>\n" \
                                     "if you have a DHCP server running on your local network. Network addresses \n" \
                                     "are then automatically obtained from the server.</p>\n"
                                 ) +
                                 # Address dialog help 4/8
                                 _(
                                   "<p>To search for an IP address and assign it statically, select \n" \
                                     "<b>Zeroconf</b>. To use DHCP and fall back to zeroconf, select <b>DHCP + Zeroconf\n" \
                                     "</b>. Otherwise, the network addresses must be assigned <b>Statically</b>.</p>\n"
                                 ),
        # Address dialog help 5/8
        "remoteip"          =>
                               _(
                                 "<p>Enter the <b>IP Address</b> (for example: <tt>192.168.100.99</tt>) for your computer, and the \n" \
                                 " <b>Remote IP Address</b> (for example: <tt>192.168.100.254</tt>)\n" \
                                 "for your peer.</p>\n"
                               ),
        # Address dialog help 6/8
        "netmask"           =>
                               _(
                                 "<p>For <b>Static Address Setup</b> enter the static IP address for your computer (for example: <tt>192.168.100.99</tt>) and\n" \
                                 "the network mask (usually <tt>255.255.255.0</tt> or just length of prefix <tt>/24</tt>).Optionally, you can enter\n" \
                                 "a fully qualified hostname for this IP address. The hostname will be written to <tt>/etc/hosts</tt>.</p>\n"
                               ) +
                                 # Address dialog help 8/8
                                 _(
                                   "<p>Contact your <b>network administrator</b> for more information about\nthe network configuration.</p>"
                                 ),
        "force_static_ip"   =>
                               _(
                                 "<p>DHCP configuration is not recommended for this product.\nComponents of this product might not work with DHCP.</p>"
                               ),
        "fwzone"            =>
                               _(
                                 "<p><b><big>Firewall Zone</big></b></p>\n" \
                                 "<p>Select the firewall zone to put the interface into. If you\n" \
                                 "select a zone, the firewall will be enabled. If you do not and other \n" \
                                 "firewalled interfaces exist, the firewall\n" \
                                 "will stay enabled but all traffic will be blocked for this\n" \
                                 "interface. If you do not select a zone and no others exist, \n" \
                                 "the firewall will be disabled.</p>"
                               ),
        "mandatory"         =>
                               _(
                                 "<p><b>Mandatory Interface</b> specifies whether the network service reports failure if the interface fails to start at boot time.</p>"
                               ),
        "mtu"               =>
                               _(
                                 "<p><b><big>Maximum Transfer Unit</big></b></p>\n" \
                                 "<p>Maximum transfer unit (<b>MTU</b>) is the maximum size of the packet,\n" \
                                 "transferred over the network in one frame. Usually, you do not need to\n" \
                                 "set a MTU, but using lower MTU values may improve the network performance,\n" \
                                 "especially on slow dial-up connections. Either select one of the recommended\n" \
                                 "values or define another one.</p>\n"
                               ),
        "bondslave"         =>
                               _(
                                 "<p>Select the slave devices for the bond device.\nOnly devices with the device activation set to <b>Never</b> and with <b>No Address Setup</b> are available.</p>"
                               ),
        "dhclient_help"     => # DHCP dialog help 1/7
                               _("<p><b><big>DHCP Client Options</big></b></p>") +
                                 # DHCP dialog help 2/7
                                 _(
                                   "<p>The <b>DHCP Client Identifier</b>, if left empty, defaults to\n" \
                                     "the hardware address of the network interface. It must be different for each\n" \
                                     "DHCP client on a single network. Therefore, specify a unique free-form\n" \
                                     "identifier here if you have several (virtual) machines using the same\n" \
                                     "network interface and thus the same hardware address.</p>"
                                 ) +
                                 # DHCP dialog help 3/7
                                 _(
                                   "<p>The <b>Hostname to Send</b> specifies a string used for the\n" \
                                     "hostname option field when the DHCP client sends messages to the DHCP server. Some \n" \
                                     "DHCP servers update name server zones (forward and reverse records) \n" \
                                     "according to this hostname (dynamic DNS).</p>\n" \
                                     "Some DHCP servers require the <b>Hostname to Send</b> option field to\n" \
                                     "contain a specific string in the DHCP messages from clients. Leave <b>AUTO</b>\n" \
                                     "to send the current hostname (for example, the one defined in <tt>/etc/HOSTNAME</tt>). \n" \
                                     "If you do not want to send a hostname, leave the field empty.</p>\n"
                                 ),
        "additional"        => # Aliases dialog help 1/4
                               _(
                                 "<p><b><big>Additional Addresses</big></b></p>\n<p>Configure additional addresses of an interface in this table.</p>\n"
                               ) +
                                 # Aliases dialog help 2/4
                                 _(
                                   "<p>Enter an <b>IPv4 Address Label</b>, an <b>IP Address</b>, and\nthe <b>Netmask</b>.</p>"
                                 ) +
                                 # Aliases dialog help 3/4
                                 _(
                                   "<p><b>IPv4 Address Label</b>, formerly known as Alias Name, is optional and legacy. The total\n" \
                                   "length of interface name (inclusive of the colon and label) is\n" \
                                   "limited to 15 characters. The obsolete ifconfig utility truncates it after 9 characters.</p>"
                                 ) +
                                 # Aliases dialog help 3/4, #83766
                                 _(
                                   "<p>Do not include the interface name in the label. For example, enter <b>foo</b> instead of <b>eth0:foo</b>.</p>"
                                 ),
        # shared between WirelessDialog and WirelessKeyPopup
        # this is suited to the button-switched key typing
        # Translators: dialog help
        "wep_key"           =>
                               _(
                                 "<p>Choose between three <b>Key Input Types</b> for your key.\n" \
                                 "<br><b>Passphrase</b>: The key is generated from the phrase entered.\n" \
                                 "<br><b>ASCII</b>: The ASCII values of the characters entered constitute the\n" \
                                 "key. Enter 5 characters for 64-bit keys, up to 13\n" \
                                 "characters for 128-bit keys, up to 16 characters for 156-bit keys, and\n" \
                                 "up to 29 characters for 256-bit keys.\n" \
                                 "<br><b>Hexadecimal</b>: Enter the hex codes of the key directly. Enter\n" \
                                 "10 hex digits for 64-bit keys, 26 digits for 128-bit keys, 32 digits\n" \
                                 "for 156-bit keys, and 58 digits for 256-bit keys. You can\n" \
                                 "use hyphens <tt>-</tt> to separate pairs or groups of digits, for example,\n" \
                                 "<tt>0a5f-41e6-48</tt>.\n" \
                                 "</p> \n"
                               ),
        "wireless"          => # Wireless dialog help
                               _(
                                 "<p>Here, set the most important settings\nfor wireless networking.</p>"
                               ) +
                                 _(
                                   "<p>The <b>Operating Mode</b> depends on the network topology. The mode\n" \
                                   "can be <b>Ad-Hoc</b> (peer-to-peer network without an access point),\n" \
                                   "<b>Managed</b> (network managed by an access point, sometimes also\n" \
                                   "called <i>Infrastructure Mode</i>), or <b>Master</b> (the network card\n" \
                                   "acts as an access point).</p>\n"
                                 ) +
                                 _(
                                   "<p>Set the <b>Network Name (ESSID)</b> used to identify\n" \
                                   "cells that are part of the same virtual network. All stations in a\n" \
                                   "wireless LAN need the same ESSID to communicate with each other. If\n" \
                                   "you choose the operation mode <b>Managed</b> and no <b>WPA</b> authentication mode,\n" \
                                   "you can leave this field empty or set it to <tt>any</tt>. In this\n" \
                                   "case, your WLAN card associates with the access point with the best\n" \
                                   "signal strength.</p>\n"
                                 ) +
                                 _(
                                   "<p>In some networks, you need to set an <b>Authentication Mode</b>.\n" \
                                   "It depends on the protection technology used, WEP or WPA. <b>WEP</b>\n" \
                                   "(Wired Equivalent Privacy) is a system to encrypt wireless network\n" \
                                   "traffic with an optional authentication, based on the encryption\n" \
                                   "key used. In most cases where WEP is used, the <b>WEP-Open</b> mode (no\n" \
                                   "authentication at all) is fine. This does not mean that you cannot\n" \
                                   "use WEP encryption (in that case use <b>No Encryption</b>). \n" \
                                   "Some networks may require <b>WEP-Shared Key</b> authentication. \n" \
                                   "NOTE: Shared key authentication makes it easier for a\n" \
                                   "potential attacker to break into your network. Unless you have\n" \
                                   "specific needs for shared key authentication, use the <b>Open</b>\n" \
                                   "mode. Because WEP has been proven insecure, <b>WPA</b> (Wi-Fi Protected Access)\n" \
                                   "was defined to close its security holes, but not all hardware supports\n" \
                                   "WPA. If you want to use WPA, select <b>WPA-PSK</b> or <b>WPA-EAP</b> as the\n" \
                                   "authentication mode. This is only possible in the operation mode\n" \
                                   "<b>Managed</b>.</p>\n"
                                 ) +
                                 _(
                                   "<p>To use WEP, enter the\n" \
                                   "WEP encryption key to use. It can have a key\n" \
                                   "length of 64, 128, 156, or 256 bits, but not all sizes are\n" \
                                   "supported by all devices. Of these keys, 24 bits\n" \
                                   "are dynamically generated, so you only need to enter 40 to 232 bits.</p>\n"
                                 ),
        "wpa"               => # Wireless dialog help
                               _(
                                 "<p>To use WPA-PSK (sometimes referred to as WPA Home),\n" \
                                 "enter the preshared key. This\n" \
                                 "key is used for authentication and encryption keys are generated from\n" \
                                 "it. These are not vulnerable to known attacks against WEP keys, but\n" \
                                 "dictionary attacks are still possible. Do not use a word that is\n" \
                                 "easy to guess as the passphrase.</p>\n"
                               ) +
                                 _(
                                   "<p>To use WPA-EAP (sometimes referred to as WPA Enterprise),\nenter some additional parameters in the next dialog.</p>\n"
                                 ) +
                                 _(
                                   "<p>These values will be written to the interface configuration file\n" \
                                   "'ifcfg-*' in '/etc/sysconfig/network'. If you need additional settings,\n" \
                                   "add them manually. Refer to the file 'wireless' in the same directory for all\n" \
                                   "available options.</p>"
                                 )
      }
    end
  end
end
