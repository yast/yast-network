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
require "y2network/interface"
require "y2network/interface_type"
require "y2network/virtual_interface"
require "y2network/physical_interface"
require "y2network/sysconfig/connection_config_reader"
require "y2network/interfaces_collection"
require "y2network/connection_configs_collection"
require "y2network/sysconfig/type_detector"
require "y2network/udev_rule"

Yast.import "LanItems"

module Y2Network
  module Sysconfig
    # This class reads interfaces configuration from sysconfig files
    #
    # * Physical interfaces are read from the hardware.
    # * Virtual interfaces + Connections are read from sysconfig.
    #
    # @see Y2Network::InterfacesCollection
    # @see Y2Network::ConnectionConfig
    class InterfacesReader
      # Returns the interfaces and connections configuration
      #
      # @return [Hash<Symbol,Object>] Returns a hash containing
      #   an interfaces collection (with the key `:interfaces`)
      #   and an array of connection config objects.
      def config
        return @config if @config
        find_physical_interfaces
        find_connections
        @config = { interfaces: @interfaces, connections: @connections }
      end

      # Convenience method to get connections configuration
      #
      # @return [Array<Y2Network::ConnectionConfig::Base>] Array of connection
      #   config objects.
      def connections
        config[:connections]
      end

      # Convenience method to get the interfaces list
      #
      # @return [Y2Network::InterfacesCollection]
      def interfaces
        config[:interfaces]
      end

    private

      # Finds the physical interfaces
      #
      # Physical interfaces are read from the old LanItems module
      def find_physical_interfaces
        return if @interfaces
        physical_interfaces = hardware.map do |h|
          build_physical_interface(h)
        end
        @interfaces = Y2Network::InterfacesCollection.new(physical_interfaces)
      end

      # Returns hardware information
      #
      # This method makes sure that the hardware information was read.
      #
      # @todo It still relies on Yast::LanItems.Hardware
      #
      # @return [Array<Hash>] Hardware information
      def hardware
        Yast::LanItems.Hardware unless Yast::LanItems.Hardware.empty?
        Yast::LanItems.ReadHw # try again if no hardware was found
        Yast::LanItems.Hardware
      end

      # Finds the connections configurations
      def find_connections
        @connections ||=
          configured_devices.each_with_object(ConnectionConfigsCollection.new([])) do |name, conns|
            interface = @interfaces.by_name(name)
            connection = ConnectionConfigReader.new.read(
              name,
              interface ? interface.type : nil
            )
            next unless connection
            add_interface(name, connection) if interface.nil?
            conns << connection
          end
      end

      # Instantiates an interface given a hash containing hardware details
      #
      # @param data [Hash] hardware information
      # @option data [String] "dev_name" Device name ("eth0")
      # @option data [String] "name"     Device description
      # @option data [String] "type"     Device type ("eth", "wlan", etc.)
      def build_physical_interface(data)
        Y2Network::PhysicalInterface.new(data["dev_name"]).tap do |iface|
          iface.description = data["name"]
          iface.renaming_mechanism = renaming_mechanism_for(iface.name)
          iface.type = InterfaceType.from_short_name(data["type"]) || TypeDetector.type_of(iface.name)
        end
      end

      # @return [Regex] expression to filter out invalid ifcfg-* files
      IGNORE_IFCFG_REGEX = /(\.bak|\.orig|\.rpmnew|\.rpmorig|-range|~|\.old|\.scpmbackup)$/

      # List of devices which has a configuration file (ifcfg-*)
      #
      # @return [Array<String>] List of configured devices
      def configured_devices
        files = Yast::SCR.Dir(Yast::Path.new(".network.section"))
        files.reject { |f| IGNORE_IFCFG_REGEX =~ f || f == "lo" }
      end

      # Adds a fake or virtual interface for a given connection
      #
      # It may happen that a configured interface is not plugged
      # while reading the configuration. In such situations, a fake one
      # should be added.
      #
      # @param name [String] Interface name
      # @param conn [ConnectionConfig] Connection configuration related to the
      #   network interface
      def add_interface(name, conn)
        interface =
          if conn.virtual?
            VirtualInterface.from_connection(name, conn)
          else
            PhysicalInterface.new(conn.name, hardware: Hwinfo.for(conn.name))
          end
        @interfaces << interface
      end

      # Detects the renaming mechanism used by the interface
      #
      # @param name [String] Interface's name
      # @return [Symbol] :mac (MAC address), :bus_id (BUS ID) or :none (no renaming)
      def renaming_mechanism_for(name)
        rule = UdevRule.find_for(name)
        return :none unless rule
        if rule.parts.any? { |p| p.key == "ATTR{address}" }
          :mac
        elsif rule.parts.any? { |p| p.key == "KERNELS" }
          :bus_id
        else
          :none
        end
      end
    end
  end
end
