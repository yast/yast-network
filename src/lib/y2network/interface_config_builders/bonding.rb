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
require "y2network/config"
require "y2network/interface_config_builder"

module Y2Network
  module InterfaceConfigBuilders
    class Bonding < InterfaceConfigBuilder
      include Yast::Logger
      extend Forwardable

      def initialize(config: nil)
        super(type: InterfaceType::BONDING, config: config)
      end

      # @return [Array<Interface>] list of interfaces usable for the bond device
      def bondable_interfaces
        interfaces.select { |i| bondable?(i) }
      end

      def_delegators :connection_config,
        :ports, :ports=

      # @param value [String] options for bonding
      def bond_options=(value)
        connection_config.options = value
      end

      # current options for bonding
      # @return [String]
      def bond_options
        connection_config.options
      end

      # Returns whether any configuration of the given devices needs to be
      # adapted in order to be added into a bonding

      # @param devices [Array<String>] devices to check
      # return [Boolean] true if there is a device config that needs
      #   to be adaptated; false otherwise
      def require_adaptation?(devices)
        devices.any? do |device|
          next false unless yast_config.configured_interface?(device)

          !valid_port_config?(device)
        end
      end

      # additionally it adapts configuration of devices to be included in a bonding if needed
      def save
        ports.each do |port|
          interface = yast_config.interfaces.by_name(port)
          next if valid_port_config?(port)

          connection = yast_config.connections.by_name(port)
          builder = InterfaceConfigBuilder.for(interface.type, config: connection)
          builder.name = interface.name
          builder.configure_as_port
          builder.startmode = "hotplug"
          builder.save
        end

        super
      end

    private

      def interfaces
        yast_config.interfaces
      end

      # Checks whether an interface can be included in particular bond interface
      #
      # @param iface [Interface] an interface to be validated as bond port
      # TODO: Check for valid configurations. E.g. bond device over vlan
      # is nonsense and is not supported by netconfig.
      # Also devices included in a bridge should be excluded too.
      def bondable?(iface)
        Yast.import "Arch"
        Yast.include self, "network/lan/s390.rb"

        # check if the device is L2 capable on s390
        if Yast::Arch.s390 && !iface.type.ethernet?
          s390_config = s390_ReadQethConfig(iface.name)

          # only devices with L2 support can be included in bond. See bnc#719881
          return false unless s390_config["QETH_LAYER2"] == "yes"
        end

        config = yast_config.connections.by_name(iface.name)
        return true unless config # unconfigured device is always bondable

        parent = config.find_parent(yast_config.connections)
        if parent && parent.name != name
          log.debug("Excluding (#{iface.name}) - already included in #{parent.inspect}")
          return false
        end

        # cannot report itself
        return false if iface.name == @name

        true
      end

      # Convenience method to check whether the config of an interface is valid
      # for including into a bond device
      #
      # @param iface [String] name of port to be validated
      def valid_port_config?(iface)
        conn = yast_config.connections.by_name(iface)

        conn&.bootproto&.name == "none" && conn&.startmode&.name == "hotplug"
      end
    end
  end
end
