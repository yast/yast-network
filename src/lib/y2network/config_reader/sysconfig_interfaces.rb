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
require "y2network/connection_config/ethernet"

Yast.import "LanItems"
Yast.import "NetworkInterfaces"

module Y2Network
  module ConfigReader
    # This class reads interfaces configuration from sysconfig files
    #
    # * Physical interfaces are read from the hardware.
    # * Virtual interfaces + Connections are read from sysconfig.
    #
    # @see Y2Network::Interface
    # @see Y2Network::Connection::Connection
    class SysconfigInterfaces
      # Returns the interfaces and connections configuration
      #
      # @todo Should we use different readers?
      # @todo Are virtual interfaces coming from connections only?
      def config
        [interfaces, connections]
      end

      # List of interfaces
      #
      # @return [InterfacesCollection]
      def interfaces
        @interfaces ||= Y2Network::InterfacesCollection.new(physical_interfaces) # + virtual_interfaces
      end

      # List of virtual interfaces
      #
      # @return [Array<Interface>]
      def virtual_interfaces
        @virtual_interfaces ||= connections.map(&:interface).compact
      end

      # @return [Array<ConnectionConfig>]
      def connections
        configured_devices.map do |name|
          interface = physical_interfaces.find { |i| i.name == name }
          conn_type = interface ? interface.type : find_type_for(name)
          # TODO: it may happen that the interface does not exist yet (hotplug, usb, or whatever)
          # How should we handle those cases?
          connection_config_for(conn_type, name)
        end
      end

    private

      # Returns the physical interfaces
      #
      # Physical interfaces are read from the old LanItems module
      #
      # @return [Array<Interface>]
      def physical_interfaces
        @physical_interfaces ||= Yast::LanItems.Hardware.map do |card|
          iface = Y2Network::PhysicalInterface.new(card["dev_name"])
          iface.description = card["name"]
          iface.type = card["type"].to_sym
          iface
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

      # Returns a connection configuration
      #
      # @param [Symbol] Connection type (e.g., :eth)
      # @param [String] Interface name
      # @return [ConnectionConfig::Base] an object representing the configuration
      def connection_config_for(type, name)
        # find type (from associated interface, name or attributes)
        # create connection from detected type
        send("#{type}_connection_config_for", name)
      end

      # Determines the type of the connection using the name
      #
      # This logic is implemented in NetworkInterfaces#GetTypeFromIfcfgOrName but, for the time
      # being, we are only using {GetTypeFromSysfs}.
      #
      # @param name [String] Interface name
      # @return [Symbol]
      def find_type_for(name)
        type = Yast::NetworkInterfaces.GetTypeFromSysfs(name)
        type.nil? ? :eth : type.to_sym
      end

      # Returns an ethernet connection configuration
      #
      # @param name [String] Interface name
      # @return [ConnectionConfig::Ethernet]
      def eth_connection_config_for(name)
        Y2Network::ConnectionConfig::Ethernet.new.tap do |conn|
          conn.interface = name
          conn.bootproto = value_from_ifcfg(name, "BOOTPROTO").to_sym
          conn.ip_address = ip_address_for(name)
        end
      end

      # Returns the interface defined in the ifcfg-* file for a given interface
      #
      # @param name [String] Interface name
      # @return [IPAddr,nil] The interface if defined
      def ip_address_for(name)
        str = value_from_ifcfg(name, "IPADDR")
        str.empty? ? nil : IPAddr.new(str)
      end

      # Returns a value from the ifcfg file for a given interface
      #
      # @param name [String] Interface name
      # @param key  [String] Configuration parameter name
      # @return [String] Value from ifcfg-*
      def value_from_ifcfg(name, key)
        path = Yast::Path.new(".network.value.\"#{name}\".#{key}")
        Yast::SCR.Read(path)
      end
    end
  end
end
