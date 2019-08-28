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
require "y2network/hwinfo"

module Y2Network
  # Network interface.
  #
  # It represents network interfaces, no matter whether they are physical or virtual ones. This
  # class (including its subclasses) are basically responsible for holding the hardware
  # configuration (see {Hwinfo}), including naming and driver information.
  #
  # Logical configuration, like TCP/IP or WIFI settings, are handled through
  # Y2Network::ConnectionConfig::Base classes. Actually, relationships with other interfaces (like
  # bonding slaves) are kept in those configuration objects too.
  #
  # @see Y2Network::PhysicalInterface
  # @see Y2Network::VirtualInterface
  # @see Y2Network::FakeInterface
  class Interface
    include Yast::Logger

    # @return [String] Device name ('eth0', 'wlan0', etc.)
    attr_accessor :name
    # @return [String] Interface description
    attr_accessor :description
    # @return [InterfaceType] Interface type
    attr_accessor :type
    # @return [Boolean]
    attr_reader :configured
    # @return [HwInfo]
    attr_reader :hardware
    # @return [Symbol] Mechanism to rename the interface (nil -no rename-, :bus_id or :mac)
    attr_accessor :renaming_mechanism
    # @return [String,nil]
    attr_reader :old_name

    # Shortcuts for accessing interfaces' ifcfg options
    #
    # TODO: this makes Interface class tighly coupled with netconfig (sysconfig) backend
    # once we have generic layer for accessing backends these methods has to be replaced
    ["STARTMODE", "BOOTPROTO"].each do |ifcfg_option|
      method_name = ifcfg_option.downcase

      define_method method_name do
        # when switching to new backend we need as much guards as possible
        if !configured || config.nil? || config.empty?
          raise "Trying to read configuration of an unconfigured interface #{@name}"
        end

        config[ifcfg_option]
      end
    end

    # Constructor
    #
    # @param name [String] Interface name (e.g., "eth0")
    # @param type [InterfaceType] Interface type
    def initialize(name, type: InterfaceType::ETHERNET)
      @name = name
      @description = ""
      @type = type
      # @hardware and @name should not change during life of the object
      @hardware = Hwinfo.for(name)

      init(name)
    end

    # Determines whether two interfaces are equal
    #
    # @param other [Interface] Interface to compare with
    # @return [Boolean]
    def ==(other)
      return false unless other.is_a?(Interface)
      name == other.name
    end

    # eql? (hash key equality) should alias ==, see also
    # https://ruby-doc.org/core-2.3.3/Object.html#method-i-eql-3F
    alias_method :eql?, :==

    # Complete configuration of the interface
    #
    # @return [Hash<String, String>] option, value hash map
    def config
      system_config(name)
    end

    # Returns the list of kernel modules
    #
    # @return [Array<Driver>]
    # @see Hwinfo#drivers
    def drivers
      hardware.drivers
    end

    # Renames the interface
    #
    # @param new_name  [String] New interface's name
    # @param mechanism [Symbol] Property to base the rename on (:mac or :bus_id)
    def rename(new_name, mechanism)
      log.info "Rename interface '#{name}' to '#{new_name}' using the '#{mechanism}'"
      @old_name = name
      @name = new_name
      @renaming_mechanism = mechanism
    end

    # Determines whether the interface can be renamed
    #
    # An interface can be renamed if it has a MAC address or a Bus ID.
    #
    # @return [Boolean]
    def can_be_renamed?
      hardware && !(hardware.mac.nil? && hardware.busid.nil?)
    end

  private

    def system_config(name)
      Yast::NetworkInterfaces.devmap(name)
    end

    def init(name)
      @configured = false
      @configured = !system_config(name).nil? if !(name.nil? || name.empty?)
    end
  end
end
