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
require "y2network/virtual_interface"
require "y2network/physical_interface"
require "y2network/fake_interface"
require "y2network/connection_config/ethernet"
require "y2network/config_reader/connection_config/sysconfig"
require "y2network/sysconfig_interface_file"

Yast.import "LanItems"
Yast.import "NetworkInterfaces"

module Y2Network
  module Sysconfig
    # This class reads interfaces configuration from sysconfig files
    #
    # * Physical interfaces are read from the hardware.
    # * Virtual interfaces + Connections are read from sysconfig.
    #
    # @see Y2Network::Interface
    # @see Y2Network::Connection::Connection
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
        physical_interfaces = Yast::LanItems.Hardware.map do |h|
          build_physical_interface(h)
        end
        @interfaces = Y2Network::InterfacesCollection.new(physical_interfaces)
      end

      # Finds the connections configurations
      def find_connections
        @connections ||=
          configured_devices.each_with_object([]) do |name, conns|
            interface = @interfaces.by_name(name)
            connection = Y2Network::ConfigReader::ConnectionConfig::Sysconfig.new.read(
              name,
              interface ? interface.type : nil
            )
            next unless connection
            add_fake_interface(name, connection) if interface.nil?
            conns << connection
          end
      end

      # Instantiates an interface given a hash containing hardware details
      #
      # If there is not information about the type, it will rely on NetworkInterfaces#GetTypeFromSysfs.
      # This responsability could be moved to the PhysicalInterface class.
      #
      # @todo Improve detection logic according to NetworkInterfaces#GetTypeFromIfcfgOrName.
      #
      # @param data [Hash] hardware information
      # @option data [String] "dev_name" Device name ("eth0")
      # @option data [String] "name"     Device description
      # @option data [String] "type"     Device type ("eth", "wlan", etc.)
      def build_physical_interface(data)
        Y2Network::PhysicalInterface.new(data["dev_name"]).tap do |iface|
          iface.description = data["name"]
          type = data["type"] || Yast::NetworkInterfaces.GetTypeFromSysfs(iface.name)
          iface.type = type.nil? ? :eth : type.to_sym
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

      # Adds a fake interface for a given connection
      #
      # It may happen that a configured interface is not plugged
      # while reading the configuration. In such situations, a fake one
      # should be added.
      #
      # @param name [String] Interface name
      # @param conn [ConnectionConfig] Connection configuration related to the
      #   network interface
      def add_fake_interface(name, conn)
        new_interface = Y2Network::FakeInterface.from_connection(name, conn)
        @interfaces << new_interface
      end
    end
  end
end
