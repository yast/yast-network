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
require "y2network/interface_type"
require "y2network/udev_rule"

module Y2Network
  # Network interface.
  #
  # It represents network interfaces, no matter whether they are physical or virtual ones. This
  # class (including its subclasses) are basically responsible for holding the hardware
  # configuration (see {Hwinfo}), including naming and driver information.
  #
  # Logical configuration, like TCP/IP or WIFI settings, are handled through
  # {Y2Network::ConnectionConfig::Base} classes. Actually, relationships with other interfaces
  # are kept in those configuration objects too.
  #
  # @see Y2Network::PhysicalInterface
  # @see Y2Network::VirtualInterface
  class Interface
    include Yast::Logger

    # @return [String] Device name ('eth0', 'wlan0', etc.)
    attr_accessor :name
    # @return [InterfaceType] Interface type
    attr_accessor :type
    # @return [HwInfo]
    attr_reader :hardware
    # @return [UdevRule]
    attr_accessor :udev_rule
    # @return [Symbol] Mechanism to rename the interface (:none -no rename-, :bus_id or :mac)
    attr_accessor :renaming_mechanism
    # @return [String,nil]
    attr_reader :old_name

    class << self
      # Builds an interface based on a connection
      #
      # @param conn [ConnectionConfig] Connection configuration related to the network interface
      def from_connection(conn)
        # require here to avoid circular dependency
        require "y2network/physical_interface"
        require "y2network/virtual_interface"

        interface_class = conn.virtual? ? VirtualInterface : PhysicalInterface
        interface_class.new(conn.interface || conn.name, type: conn.type)
      end
    end

    # Constructor
    #
    # @param name [String] Interface name (e.g., "eth0")
    # @param type [InterfaceType] Interface type
    def initialize(name, type: InterfaceType::ETHERNET)
      @name = name.freeze
      @type = type
      # TODO: move renaming logic to physical interfaces only
      @renaming_mechanism = :none
    end

    # Whether the interface is connected or not based on hardware information
    #
    # @see Hwinfo#connected?
    # @return [Boolean]
    def connected?
      !!hardware&.connected?
    end

    # Returns the list of kernel modules
    #
    # @return [Array<Driver>]
    # @see Hwinfo#drivers
    def drivers
      hardware&.drivers || []
    end

    # Determines whether two interfaces are equal
    #
    # @note although it is preferable to use Yast2::Equatable it uses the class
    #   hash for comparing objects and it will fail when comparing with
    #   subclasses objects (bsc#1188908)
    # @param other [Interface] Interface to compare with
    # @return [Boolean]
    def ==(other)
      return false unless other.is_a?(Interface)

      name == other.name
    end

    # eql? (hash key equality) should alias ==, see also
    # https://ruby-doc.org/core-2.3.3/Object.html#method-i-eql-3F
    alias_method :eql?, :==

    # Used by Array or Hash in order to compare equality of elements (bsc#1186082)
    def hash
      name.hash
    end

    # Complete configuration of the interface
    #
    # @return [Hash<String, String>] option, value hash map
    def config
      system_config(name)
    end

    # Renames the interface
    #
    # @param new_name  [String] New interface's name
    # @param mechanism [Symbol] Property to base the rename on (:mac or :bus_id)
    def rename(new_name, mechanism)
      log.info "Rename interface '#{name}' to '#{new_name}' using the '#{mechanism}'"
      @old_name = name if name != new_name # same name, just set different mechanism
      @name = new_name.freeze
      @renaming_mechanism = mechanism
    end

    # Updates or creates the associated udev rule depending on the renaming
    # mechanism selected
    #
    # @return [UdevRule] udev rule
    def update_udev_rule
      log.info("Updating udev rule for #{name} based on: #{renaming_mechanism.inspect}")

      case renaming_mechanism
      when :mac
        udev_rule&.rename_by_mac(name, hardware.mac)

        @udev_rule ||= Y2Network::UdevRule.new_mac_based_rename(name, hardware.mac)
      when :bus_id
        udev_rule&.rename_by_bus_id(name, hardware.busid, hardware.dev_port)

        @udev_rule ||=
          Y2Network::UdevRule.new_bus_id_based_rename(name, hardware.busid, hardware.dev_port)
      end
    end

    # @return [Boolean] true if the interface is hotplug
    def hotplug?
      return false unless hardware

      ["usb", "pcmcia"].include?(hardware.hotplug)
    end
  end
end
