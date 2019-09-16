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
require "forwardable"
require "y2network/config"
require "y2network/interface_config_builder"

Yast.import "NetworkInterfaces"

module Y2Network
  module InterfaceConfigBuilders
    class Bridge < InterfaceConfigBuilder
      include Yast::Logger
      extend Forwardable

      def initialize(config: nil)
        super(type: InterfaceType::BRIDGE, config: config)
      end

      # Checks if any of given device is already configured and need adaptation for bridge
      def already_configured?(devices)
        devices.any? do |device|
          next false if Yast::NetworkInterfaces.devmap(device).nil?
          ![nil, "none"].include?(Yast::NetworkInterfaces.devmap(device)["BOOTPROTO"])
        end
      end

      # @return [Array<Interface>] list of interfaces usable in the bridge
      def bridgeable_interfaces
        interfaces.select { |i| bridgeable?(i) }
      end

      def_delegators :@connection_config,
        :ports, :ports=,
        :stp, :stp=

    private

      def interfaces
        Config.find(:yast).interfaces
      end

      NONBRIDGEABLE_TYPES = [
        InterfaceType::BRIDGE,
        InterfaceType::TUN,
        InterfaceType::USB,
        InterfaceType::WIRELESS
      ].freeze
      NONBRIDGEABLE_STARTMODE = ["nfsroot", "ifplugd"].freeze

      # Checks whether an interface can be bridged in particular bridge
      #
      # @param iface [Interface] an interface to be validated as the bridge slave
      def bridgeable?(iface)
        # cannot enslave itself
        # FIXME: this can happen only bcs we silently use LanItems::Items which
        # already contains partially configured bridge when adding
        return false if iface.name == @name
        return true unless yast_config.configured_interface?(iface.name)

        if interfaces.bond_index[iface.name]
          log.debug("Excluding (#{iface.name}) - is bonded")
          return false
        end

        # the iface is already in another bridge
        if interfaces.bridge_index[iface.name] && interfaces.bridge_index[iface.name] != @name
          log.debug("Excluding (#{iface.name}) - already bridged")
          return false
        end

        # exclude interfaces of type unusable for bridge
        if NONBRIDGEABLE_TYPES.include?(iface.type)
          log.debug("Excluding (#{iface.name}) - is #{iface.type.name}")
          return false
        end

        if NONBRIDGEABLE_STARTMODE.include?(iface.startmode)
          log.debug("Excluding (#{iface.name}) - is #{iface.startmode}")
          return false
        end

        true
      end
    end
  end
end
