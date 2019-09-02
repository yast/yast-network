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
require "y2network/boot_protocol"
require "y2network/startmode"

module Y2Network
  module ConnectionConfig
    # This class is reponsible of a connection configuration
    #
    # It holds a configuration (IP addresses, MTU, WIFI settings, etc.) that can be applied to an
    # interface. By comparison, it is the equivalent of the "Connection" concept in NetworkManager.
    # When it comes to sysconfig, a "ConnectionConfig" is defined using a "ifcfg-*" file.
    class Base
      # A connection could belongs to a specific interface or not. In case of
      # no specific interface then it could be activated by the first available
      # device.
      #
      # @return [String] Connection name
      attr_accessor :name

      # @return [String, nil] Interface to apply the configuration to
      # FIXME: Maybe in the future it could be a matcher. By now we will use
      #   the interface's name.
      attr_accessor :interface

      # @return [BootProtocol] Bootproto
      attr_accessor :bootproto
      # @return [IPConfig] Primary IP configuration
      attr_accessor :ip
      # @return [Array<IPConfig>] Additional IP configurations (also known as 'aliases')
      attr_accessor :ip_aliases
      # @return [Integer, nil]
      attr_accessor :mtu
      # @return [Startmode, nil]
      attr_accessor :startmode
      # @return [String] Connection's description (e.g., "Ethernet Card 0")
      attr_accessor :description
      # @return [String] Link layer address
      attr_accessor :lladdress

      # Constructor
      def initialize
        @ip_aliases = []
        @bootproto = BootProtocol::STATIC # TODO: maybe do test query if physical interface is attached?
        @startmode = Startmode.create("manual")
      end

      # Propose reasonable defaults for given config. Useful for newly created devices.
      # @note difference between constructor and propose is that initialize should set simple defaults
      #   and propose have more tricky config that depends on env, product, etc.
      def propose
        propose_startmode
      end

      def propose_startmode
        Yast.import "ProductFeatures"

        product_startmode = Yast::ProductFeatures.GetStringFeature(
          "network",
          "startmode"
        )

        startmode = case product_startmode
        when "ifplugd"
          if replace_ifplugd?
            hotplug_interface? ? "hotplug" : "auto"
          else
            product_startmode
          end
        when "auto"
          "auto"
        else
          hotplug_interface? ? "hotplug" : "auto"
        end

        @startmode = Startmode.create(startmode)
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

      # Returns all IP configurations
      #
      # @return [Array<IPConfig>]
      def all_ips
        ([ip] + ip_aliases).compact
      end

    private

      def replace_ifplugd?
        Yast.import "Arch"

        return true if !Yast::Arch.is_laptop
        # virtual devices cannot expect any event from ifplugd
        return true if virtual?

        false
      end

      def hotplug_interface?
        # virtual interface is not hotplugable
        return false if virtual?
        # if interface is not there
        return true unless interface

        interface.hardware.hotplug
      end
    end
  end
end
