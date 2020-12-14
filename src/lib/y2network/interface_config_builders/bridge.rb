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

module Y2Network
  module InterfaceConfigBuilders
    class Bridge < InterfaceConfigBuilder
      include Yast::Logger
      extend Forwardable

      def initialize(config: nil)
        super(type: InterfaceType::BRIDGE, config: config)
      end

      # Returns whether any configuration of the given devices needs to be
      # adapted in order to be added as a bridge port
      #
      # @param devices [Array<String>] devices to check
      # @return [Boolean] true if there is a device config that needs
      #   to be adaptated; false otherwise
      def require_adaptation?(devices)
        devices.any? do |device|
          next false unless yast_config.configured_interface?(device)

          yast_config.connections.by_name(device).bootproto.name != "none"
        end
      end

      # @return [Array<Interface>] list of interfaces usable in the bridge
      def bridgeable_interfaces
        interfaces.select { |i| bridgeable?(i) }
      end

      # additionally it adapt slaves if needed
      def save
        ports.each do |port|
          interface = yast_config.interfaces.by_name(port)

          connection = yast_config.connections.by_name(port)
          next if connection && connection.startmode.name == "none"

          builder = InterfaceConfigBuilder.for(interface.type, config: connection)
          builder.name = interface.name
          builder.configure_as_slave
          builder.save
        end

        super
      end

      def configure_from(connection)
        [:bootproto, :ip, :ip_aliases, :startmode, :description,
         :firewall_zone, :hostnames].all? do |method|
          @connection_config.public_send("#{method}=", connection.public_send(method))
        end
      end

      def_delegators :@connection_config,
        :ports, :ports=,
        :stp, :stp=

    private

      def interfaces
        yast_config.interfaces
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
        return false if iface.name == @name
        return true unless yast_config.configured_interface?(iface.name)

        config = yast_config.connections.by_name(iface.name)
        master = config.find_master(yast_config.connections)
        if master && master.name != name
          log.debug("Excluding (#{iface.name}) - already has master #{master.inspect}")
          return false
        end

        # exclude interfaces of type unusable for bridge
        if NONBRIDGEABLE_TYPES.include?(iface.type)
          log.debug("Excluding (#{iface.name}) - is #{iface.type.name}")
          return false
        end

        if NONBRIDGEABLE_STARTMODE.include?(config.startmode.to_s)
          log.debug("Excluding (#{iface.name}) - is #{config.startmode}")
          return false
        end

        true
      end
    end
  end
end
