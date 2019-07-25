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

require "y2network/interface_type"

module Y2Network
  module ConnectionConfig
    # This class is reponsible of a connection configuration
    #
    # It holds a configuration (IP addresses, MTU, etc.) that can be applied to an interface. By
    # comparison, it is the equivalent of the "Connection" concept in NetworkManager.  When it comes
    # to sysconfig, a "ConnectionConfig" is defined using a "ifcfg-*" file.
    class Base
      # A connection could belongs to a specific interface or not. In case of
      # no specific interface then it could be activated by the first available
      # device.
      #
      # @return [String] Connection name
      attr_accessor :name
      # #FIXME: Maybe it could be a matcher instead of an Interface or just
      # the interface name by now.
      #
      # @return [Interface, nil]
      attr_accessor :interface
      # @return [BootProtocol] Bootproto
      attr_accessor :bootproto
      # @return [Array<IPConfig>]
      attr_accessor :ip_configs
      # @return [Integer, nil]
      attr_accessor :mtu
      # @return [Startmode, nil]
      attr_accessor :startmode
      # @return [String] Connection's description (e.g., "Ethernet Card 0")
      attr_accessor :description

      # Constructor
      def initialize
        @ip_configs = []
      end

      # Returns the connection type
      #
      # Any subclass could define this method is the default
      # logic does not match.
      #
      # @return [InterfaceType] Interface type
      def type
        const_name = self.class.name.split("::").last.upcase
        InterfaceType.const_get(const_name)
      end

      # Whether a connection needs a virtual device associated or not.
      #
      # @return [Boolean]
      def virtual?
        false
      end
    end
  end
end
