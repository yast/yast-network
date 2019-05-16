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

require "y2network/interface"

module Y2Network
  module ConnectionConfig
    # This class is reponsible of a connection configuration
    class Base
      # A connection could belongs to a specific interface or not. In case of
      # no specific interface then it could be activated by the first available
      # device.
      #
      # #FIXME: Maybe it could be a matcher instead of an Interface, or just a
      # the interface name by now.
      #
      # @return [Interface, nil]
      attr_accessor :interface
      # @return [String] Bootproto (static, dhcp, ,dhcp4, dhcp6, autoip,
      #   dhcp+autoip, auto6, 6to4, none)
      attr_accessor :bootproto
      # @return [IPAddr,nil]
      attr_accessor :ip_address
      # @return [Array<IPAddr>]
      attr_accessor :secondary_ip_addresses
      # @return [Integer, nil]
      attr_accessor :mtu
    end
  end
end
