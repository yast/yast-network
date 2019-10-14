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
                                 "<p><b><big>Initializing Network Card\n" \
                                   "Configuration</big></b><br>Please wait...<br></p>\n"
                               ) +
                                 # Network cards read dialog help 2/2
                                 _(
                                   "<p><b><big>Aborting the Initialization:</big></b><br>\n" \
                                     "Safely abort the configuration utility by pressing" \
                                     "<B>Abort</B> now.</p>\n"
                                 ),
        "write"             => # Network cards write dialog help 1/2
                               _(
                                 "<p><b><big>Saving Network Card\n" \
                                   "Configuration</big></b><br>Please wait...<br></p>\n"
                               ) +
                                 # Network cards write dialog help 2/2
                                 _(
                                   "<p><b><big>Aborting Saving:</big></b><br>\n" \
                                     "Abort saving by pressing <b>Abort</b>.</p>\n"
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
                                   "<p>Use <b>wicked</b> if you do not run a desktop " \
                                     "environment\n" \
                                     "or need to use multiple interfaces at the same time.</p>\n"
                                 ) +
                                 # For systems not including NetworkManager by default (bnc#892678)
                                 _(
                                   "<p><b>NetworkManager</b> is not part of every base\n" \
                                   "installation repository. For example, to enable it on SUSE\n" \
                                   "Linux Enterprise Server add the Workstation Extension\n" \
                                   "repository and install the 'NetworkManager' package.</p>\n"
                                 ),
        "ipv6"              =>
                               # IPv6 help
                               _(
                                 "<p><b><big>IPv6 Protocol Settings</big></b></p>\n" \
                                   "<p>Check <b>Enable IPv6</b> to enable the ipv6 " \
                                   "module in the kernel.\n" \
                                   "It is possible to use IPv6 together with IPv4. " \
                                   "This is the default option.\n" \
                                   "To disable IPv6, uncheck this option. " \
                                   "This will blacklist the kernel \n" \
                                   "module for ipv6. If the IPv6 protocol " \
                                   "is not used on your network, the response \n" \
                                   "time can be faster.</p>\n"
                               ) +
                                 _("<p>All changes will be applied after reboot.</p>"),
        "searchlist_s"      =>
                               _(
                                 "<p>Enter the name servers and domain search list for resolving " \
                                   "\nhostnames. Usually they can be obtained by DHCP.</p>\n"
                               ) +
                                 # resolver dialog help
                                 _(
                                   "<p>A name server is a computer that translates " \
                                     "hostnames into\n" \
                                     "IP addresses. This value must be entered as an " \
                                     "<b>IP address</b>\n" \
                                     "(for example, 192.168.0.42), not as a hostname.</p>\n"
                                 ) +
                                 # resolver dialog help
                                 _(
                                   "<p>Search domain is the domain name where hostname " \
                                     "searching starts.\n" \
                                     "The primary search domain is usually the same as the " \
                                     "domain name of\n" \
                                     "your computer (for example, suse.de). There may be " \
                                     "additional search domains\n" \
                                     "(such as suse.com). Separate the domains with commas " \
                                     "or white space.</p>\n"
                                 ),
        "hostname_global"   =>
                               _(
                                 "<p>Enter local name for this computer (e.g. <i>mymachine</i>). " \
                                   "The name will\n" \
                                   "be stored in <i>/etc/hostname</i>. You can also choose " \
                                   "whether the hostname can\n" \
                                   "be obtained from DHCP. In such case you can pick particular " \
                                   "dhcp interface which\n" \
                                   "will be used for obtaining the hostname or leave it up to " \
                                   "the network service.</p>\n"
                               ),
        "dns_config_policy" =>
                               _(
                                 "<p>Select the way how the DNS configuration will " \
                                   "be modified (name servers,\n" \
                                   "search list, the content of <i>/etc/resolv.conf</i>). " \
                                   "Normally, it is handled\n" \
                                   "by the <i>netconfig</i> script, which merges statically " \
                                   "defined data with\n" \
                                   "dynamically obtained data (e.g. from the DHCP client, " \
                                   "NetworkManager,\n" \
                                   "etc.). This is the default. <b>Use Default Policy</b> is " \
                                   "sufficient for most\n" \
                                   "configurations.</p>\n"
                               ) +
                                 _(
                                   "<p>By choosing <b>Only Manually</b>, <i>netconfig</i> will " \
                                     "no longer be\n" \
                                     "allowed to modify <i>/etc/resolv.conf</i>. You can " \
                                     "however edit the file\n" \
                                     "manually. By choosing <b>Use Custom Policy</b>, you may " \
                                     "specify a custom\n" \
                                     "policy string, which consists of a comma-separated list " \
                                     "of interface names,\n" \
                                     "including wildcards, with STATIC and STATIC_FALLBACK " \
                                     "as predefined special\n" \
                                     "values. For more information, see the <i>netconfig</i> " \
                                     "manual page. Note:\n" \
                                     "Leaving the field blank is the same as using the " \
                                     "<b> Only Manually</b>\n" \
                                     "policy.</p>\n"
                                 ),
        "dhclient_help"     => # DHCP dialog help 1/7
                               _("<p><b><big>DHCP Client Options</big></b></p>") +
                                 # DHCP dialog help 2/7
                                 _(
                                   "<p>The <b>DHCP Client Identifier</b>, if left empty, " \
                                     "defaults to\n" \
                                     "the hardware address of the network interface. It " \
                                     "must be different for each\n" \
                                     "DHCP client on a single network. Therefore, specify " \
                                     "a unique free-form\n" \
                                     "identifier here if you have several (virtual) machines " \
                                     "using the same\n" \
                                     "network interface and thus the same hardware address.</p>"
                                 ) +
                                 # DHCP dialog help 3/7
                                 _(
                                   "<p>The <b>Hostname to Send</b> specifies a string " \
                                     "used for the\n" \
                                     "hostname option field when the DHCP client sends messages " \
                                     "to the DHCP server. Some \n" \
                                     "DHCP servers update name server zones (forward and " \
                                     "reverse records) \n" \
                                     "according to this hostname (dynamic DNS).</p>\n" \
                                     "Some DHCP servers require the <b>Hostname to Send</b> " \
                                     "option field to\n" \
                                     "contain a specific string in the DHCP messages from " \
                                     "clients. Leave <b>AUTO</b>\n" \
                                     "to send the current hostname (for example, the one " \
                                     "defined in <tt>/etc/HOSTNAME</tt>). \n" \
                                     "If you do not want to send a hostname, " \
                                     "leave the field empty.</p>\n"
                                 )
      }
    end
  end
end
