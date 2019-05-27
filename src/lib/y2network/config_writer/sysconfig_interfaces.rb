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
require "yast"

module Y2Network
  module ConfigWriter
    class SysconfigInterfaces
      COMMON_KEYS = [
        "BOOTPROTO", "BROADCAST", "ETHTOOL_OPTIONS", "IPADDR", "MTU", "NAME", "NETWORK",
        "REMOTE_IPADDR", "STARTMODE", "PREFIXLEN", "NETMASK"
      ].freeze

      def write(interfaces)
        interfaces.each { |i| write_interface(i) }
        Yast::SCR.Write(Yast::Path.new(".network"), nil)
      end

    private

      def write_interface(iface)
        interface_to_hash(iface)
      end

      def interface_to_hash(iface)
        {
          "NAME" => iface.name
        }
      end
    end
  end
end
