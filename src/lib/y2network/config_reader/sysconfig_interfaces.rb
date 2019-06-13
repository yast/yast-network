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
require "y2network/config_reader/connection_config/sysconfig"
require "y2network/sysconfig_interface_file"

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
        configured_devices.each_with_object([]) do |name, connections|
          interface = physical_interfaces.find { |i| i.name == name }
          # TODO: it may happen that the interface does not exist yet (hotplug, usb, or whatever)
          # How should we handle those cases?
          next if interface.nil?
          connection = Y2Network::ConfigReader::ConnectionConfig::Sysconfig.new.read(interface)
          connections << connection if connection
        end
      end

    private

      # Returns the physical interfaces
      #
      # Physical interfaces are read from the old LanItems module
      #
      # @return [Array<Interface>]
      def physical_interfaces
        return @physical_interfaces if @physical_interfaces
        Yast::LanItems.Hardware.map { |h| build_physical_interface(h) }
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
    end
  end
end
