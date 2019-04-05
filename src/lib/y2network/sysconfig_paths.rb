# Copyright (c) [2019] SUSE LLC
#
# All Rights Reserved.
#
# This program is free software; you can redistribute it and/or modify it
# under the terms of version 2 of the GNU General Public License as published
# by the Free Software Foundation.
#
# This program is distributed in the hope that it will be useful, but WITHOUT
# ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or
# FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License for
# more details.
#
# You should have received a copy of the GNU General Public License along
# with this program; if not, contact SUSE LLC.
#
# To contact SUSE LLC about this file by physical or electronic mail, you may
# find current contact information at www.suse.com.

module Y2Network
  # Various constants which tells what can be found where in sysconfig
  module SysconfigPaths
    # sysctl keys, used as *single* SCR path components below
    IPV4_SYSCTL = "net.ipv4.ip_forward".freeze
    IPV6_SYSCTL = "net.ipv6.conf.all.forwarding".freeze

    private_constant :IPV4_SYSCTL
    private_constant :IPV6_SYSCTL

    # SCR paths IPv4 / IPv6 Forwarding
    SYSCTL_AGENT_PATH = ".etc.sysctl_conf".freeze
    SYSCTL_IPV4_PATH = (SYSCTL_AGENT_PATH + ".\"#{IPV4_SYSCTL}\"").freeze
    SYSCTL_IPV6_PATH = (SYSCTL_AGENT_PATH + ".\"#{IPV6_SYSCTL}\"").freeze
  end
end
