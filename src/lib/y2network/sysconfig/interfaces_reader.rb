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
require "y2network/sysconfig/interface_file"
require "y2network/interfaces_collection"
require "y2network/connection_configs_collection"
require "y2network/sysconfig/type_detector"
require "y2network/udev_rule"

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
        find_drivers
        @config = { interfaces: @interfaces, connections: @connections, drivers: @drivers }
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

      # Convenience method to get the drivers list
      #
      # @return [Array<Y2Network::Driver>]
      def drivers
        config[:drivers]
      end

    private

      # Finds the physical interfaces
      def find_physical_interfaces
        return if @interfaces
        physical_interfaces = Hwinfo.netcards.map do |h|
          build_physical_interface(h)
        end
        @interfaces = Y2Network::InterfacesCollection.new(physical_interfaces)
      end

      # Finds the connections configurations
      def find_connections
        @connections ||=
          InterfaceFile.all.each_with_object(ConnectionConfigsCollection.new([])) do |file, conns|
            interface = @interfaces.by_name(file.interface)
            connection = ConnectionConfigReader.new.read(
              file.interface,
              interface ? interface.type : nil
            )
            next unless connection
            add_interface(connection) if interface.nil?
            conns << connection
          end
      end

      # Finds the available drivers
      def find_drivers
        physical_interfaces = @interfaces.physical
        drivers_names = physical_interfaces.flat_map(&:drivers).map(&:name)
        drivers_names += @interfaces.physical.map(&:custom_driver).compact
        drivers_names.uniq!

        @drivers = drivers_names.map do |name|
          Y2Network::Driver.from_system(name)
        end
      end

      # Instantiates an interface given a hash containing hardware details
      #
      # @param hwinfo [Hash] hardware information
      def build_physical_interface(hwinfo)
        Y2Network::PhysicalInterface.new(hwinfo.dev_name, hardware: hwinfo).tap do |iface|
          iface.renaming_mechanism = renaming_mechanism_for(iface)
          iface.custom_driver = custom_driver_for(iface)
          iface.type = InterfaceType.from_short_name(hwinfo.type) || TypeDetector.type_of(iface.name)
        end
      end

      # Adds a fake or virtual interface for a given connection
      #
      # It may happen that a configured interface is not plugged
      # while reading the configuration. In such situations, a fake one
      # should be added.
      #
      # @param conn [ConnectionConfig] Connection configuration related to the
      #   network interface
      def add_interface(conn)
        interface =
          if conn.virtual?
            VirtualInterface.from_connection(conn)
          else
            PhysicalInterface.new(conn.name, hardware: Hwinfo.for(conn.name))
          end
        @interfaces << interface
      end

      # Detects the renaming mechanism used by the interface
      #
      # @param iface [PhysicalInterface] Interface
      # @return [Symbol] :mac (MAC address), :bus_id (BUS ID) or :none (no renaming)
      def renaming_mechanism_for(iface)
        rule = UdevRule.find_for(iface.name)
        return :none unless rule
        if rule.parts.any? { |p| p.key == "ATTR{address}" }
          :mac
        elsif rule.parts.any? { |p| p.key == "KERNELS" }
          :bus_id
        else
          :none
        end
      end

      # Detects the custom driver used by the interface
      #
      # A driver is considered "custom" is it was set by the user through a udev rule.
      #
      # @param iface [PhysicalInterface] Interface to fetch the custom driver
      # @return [String,nil] Custom driver (or nil if not set)
      def custom_driver_for(iface)
        return nil unless iface.modalias
        rule = UdevRule.all(:drivers).find { |r| r.original_modalias == iface.modalias }
        rule ? rule.driver : nil
      end
    end
  end
end
