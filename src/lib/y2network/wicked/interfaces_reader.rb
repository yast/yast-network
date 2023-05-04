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
require "network/wicked"
require "y2network/interface"
require "y2network/interface_type"
require "y2network/virtual_interface"
require "y2network/physical_interface"
require "y2network/s390_group_device"
require "y2network/wicked/connection_config_reader"
require "cfa/interface_file"
require "y2network/connection_configs_collection"
require "y2network/hwinfo"
require "y2network/interfaces_collection"
require "y2network/s390_group_devices_collection"
require "y2network/udev_rule"
require "y2network/wicked/type_detector"

Yast.import "Arch"

module Y2Network
  module Wicked
    # This class reads physical interfaces and drivers
    #
    # @see Y2Network::InterfacesCollection
    class InterfacesReader
      include Yast::Wicked
      # Returns the collection of s390 group devices
      #
      # @return [Array<Y2Network::ConnectionConfig::Base>] Array of connection
      #   config objects.
      def s390_devices
        return @s390_devices if @s390_devices

        devices = Yast::Arch.s390 ? S390GroupDevice.all : []
        @s390_devices = Y2Network::S390GroupDevicesCollection.new(devices)
      end

      # Returns the collection of physical interfaces
      #
      # @return [Y2Network::InterfacesCollection]
      def interfaces
        return @interfaces if @interfaces

        Hwinfo.reset
        physical_interfaces = Hwinfo.netcards.each_with_object([]) do |hwinfo, interfaces|
          physical_interface = build_physical_interface(hwinfo)
          next if physical_interface.type == InterfaceType::UNKNOWN
          next if physical_interface.name.to_s.empty?

          interfaces << physical_interface
        end

        @interfaces = Y2Network::InterfacesCollection.new(physical_interfaces)
      end

      # Finds the available drivers
      #
      # The available drivers are extracted from the physical interface
      # drivers.
      #
      # @return [Array<Y2Network::Driver>] List of drivers
      def drivers
        return @drivers if @drivers

        physical_interfaces = interfaces.physical
        drivers_names = physical_interfaces.flat_map(&:drivers).map(&:name)
        drivers_names += interfaces.physical.map(&:custom_driver).compact
        drivers_names.uniq!
        @drivers = drivers_names.map { |n| Y2Network::Driver.from_system(n) }
      end

    private

      # Instantiates an interface given a hash containing hardware details
      #
      # @param hwinfo [Hash] hardware information
      def build_physical_interface(hwinfo)
        Y2Network::PhysicalInterface.new(hwinfo.dev_name, hardware: hwinfo).tap do |iface|
          iface.udev_rule = UdevRule.find_for(iface.name)
          iface.renaming_mechanism = renaming_mechanism_for(iface)
          iface.custom_driver = custom_driver_for(iface)
          iface.type = InterfaceType.from_short_name(hwinfo.type) ||
            TypeDetector.type_of(iface.name) || InterfaceType::UNKNOWN
          iface.firmware_configured_by = firmware_configured_by?(iface.name)
        end
      end

      # Detects the renaming mechanism used by the interface
      #
      # @param iface [PhysicalInterface] Interface
      # @return [Symbol] :mac (MAC address), :bus_id (BUS ID) or :none (no renaming)
      def renaming_mechanism_for(iface)
        rule = iface.udev_rule
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

        rule = UdevRule.drivers_rules.find { |r| r.original_modalias == iface.modalias }
        rule ? rule.driver : nil
      end
    end
  end
end
