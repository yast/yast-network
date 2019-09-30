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
require "y2network/driver"
require "y2network/udev_rule"

Yast.import "LanItems"

module Y2Network
  # A helper for {Hwinfo}.
  class HardwareWrapper
    def initialize
      Yast.include self, "network/routines.rb"
    end

    # Returns the network devices hardware information
    #
    # @return [Array<Hwinfo>] Hardware information for netword devices
    def netcards
      return @netcards if @netcards
      read_hardware
      @netcards = ReadHardware("netcard").map do |attrs|
        name = attrs["dev_name"]
        extra_attrs = name ? extra_attrs_for(name) : {}
        Hwinfo.new(attrs.merge(extra_attrs))
      end
    end

  private

    # Add aditional attributes
    #
    # @param name [String] Device name
    # @return [Hash] Hash containing extra attributes
    def extra_attrs_for(name)
      extra = {}
      raw_dev_port = Yast::SCR.Read(
        Yast::Path.new(".target.string"), "/sys/class_net/#{name}/dev_port"
      ).to_s.strip
      extra["dev_port"] = raw_dev_port unless raw_dev_port.empty?
      extra
    end

    # Makes sure that the hardware information was read
    def read_hardware
      Yast::LanItems.ReadHw if Yast::LanItems.Hardware.empty?
    end
  end

  # Stores useful (from networking POV) items of hwinfo for an interface.
  # FIXME: decide whether it should read hwinfo (on demand or at once) for a network
  # device and store only necessary info or just parse provided hash
  class Hwinfo
    # TODO: this method should be private
    # @return [Hash]
    attr_reader :hwinfo

    class << self
      # Creates a new instance containing hardware information for a given interface
      #
      # It retrieves the information from two sources:
      #
      # * hardware (through {Yast::LanItems} for the time being),
      # * from existing udev rules.
      #
      # @todo Probably, this logic should be moved to a separate class.
      #
      # @param name [String] Interface's name
      # @return [Hwinfo]
      def for(name)
        hwinfo_from_hardware(name) || hwinfo_from_udev(name) || Hwinfo.new
      end

      # Returns the network devices hardware information
      #
      # @return [Array<Hwinfo>] Hardware information for netword devices
      def netcards
        hardware_wrapper.netcards
      end

      # Resets the hardware information
      #
      # It will be re-read the next time is needed.
      def reset
        @hardware_wrapper = nil
      end

    private

      # Returns hardware information for the given device
      #
      # It relies on the {Yast::LanItems} module.
      #
      # @param name [String] Interface's name
      # @return [Hwinfo,nil] Hardware info or nil if not found
      def hwinfo_from_hardware(name)
        hardware_wrapper.netcards.find { |h| h.dev_name == name }
      end

      # Hardware wrapper instance
      #
      # It memoizes the hardware wrapper in order to speed up the access
      #
      # @return [HardWrapper]
      def hardware_wrapper
        @hardware_wrapper = HardwareWrapper.new
      end

      # Returns hardware information for the given device
      #
      # It relies on udev rules.
      #
      # @param name [String] Interface's name
      # @return [Hwinfo,nil] Hardware info or nil if not found
      def hwinfo_from_udev(name)
        udev_rule = UdevRule.find_for(name)
        return nil if udev_rule.nil?
        info = {
          udev:     udev_rule.bus_id,
          mac:      udev_rule.mac,
          dev_port: udev_rule.dev_port
        }.compact
        new(info)
      end
    end

    # Constructor
    #
    # @param hwinfo [Hash<String,Object>] Hardware information
    def initialize(hwinfo = {})
      # FIXME: store only what's needed.
      @hwinfo = Hash[hwinfo.map { |k, v| [k.to_s, v] }]
    end

    # Shortcuts for accessing hwinfo items. Each hwinfo item has own method for reading
    # its value. There are two exceptions however. First exception is hwinfo["name"] item
    # which carries device model human friendly description. This item is accessible via
    # {Hwinfo::description}. Second exception is hwinfo["dev_name"] item which can be read
    # through {Hwinfo::dev_name} or its alias {Hwinfo::name}.
    #
    # @!method dev_name read value of hwinfo["dev_name"]
    #   @return [String]
    # @!method mac read value of hwinfo["mac"]
    #   @return [String]
    # @!method busid read value of hwinfo["busid"]
    #   @return [String]
    # @!method link read value of hwinfo["link"]
    #   @return [Boolean]
    # @!method driver read value of hwinfo["driver"]
    #   @return [String]
    # @!method drivers read value of hwinfo["drivers"]
    #   @return [Array<String>]
    # @!method requires read value of hwinfo["requires"]
    #   @return [Array<String>]
    # @!method hotplug read value of hwinfo["hotplug"]
    #   @return [Boolean]
    # @!method module read value of hwinfo["module"]
    #   @return [String]
    # @!method wl_auth_modes read value of hwinfo["wl_auth_modes"]
    #   @return [String]
    # @!method wl_enc_modes read value of hwinfo["wl_enc_modes"]
    #   @return [Array<String>,nil]
    # @!method wl_channels read value of hwinfo["wl_channels"]
    #   @return [Array<String>, nil]
    # @!method wl_bitrates read value of hwinfo["wl_bitrates"]
    #   @return [String,nil]
    [
      { name: "dev_name", default: "" },
      { name: "permanent_mac", default: nil },
      { name: "busid", default: nil },
      { name: "link", default: false },
      { name: "driver", default: "" },
      { name: "module", default: nil },
      { name: "requires", default: [] },
      { name: "hotplug", default: false },
      { name: "wl_auth_modes", default: "" },
      { name: "wl_enc_modes", default: nil },
      { name: "wl_channels", default: nil },
      { name: "wl_bitrates", default: nil },
      { name: "dev_port", default: nil },
      { name: "type", default: nil },
      { name: "name", default: "" },
      { name: "modalias", default: nil }
    ].each do |hwinfo_item|
      define_method hwinfo_item[:name].downcase do
        @hwinfo ? @hwinfo.fetch(hwinfo_item[:name], hwinfo_item[:default]) : hwinfo_item[:default]
      end
    end

    # @return [<String>] device name, @see dev_name
    alias_method :name, :dev_name

    def exists?
      !@hwinfo.empty?
    end

    # Device type description
    # FIXME: collision with alias for dev_name
    def description
      @hwinfo ? @hwinfo.fetch("name", "") : ""
    end

    # Merges data from another Hwinfo object
    #
    # @param other [Hwinfo] Object to merge data from
    def merge!(other)
      @hwinfo.merge!(other.hwinfo)
      self
    end

    # Returns the list of kernel modules
    #
    # The list of modules is internally represented as:
    #
    #   [[mod1name, mod1args], [mod2name, mod2args]]
    #
    # This method only returns the names, omitting the arguments.
    #
    # @return [Array<Driver>] List of drivers
    def drivers
      driver = @hwinfo.fetch("drivers", []).first
      return [] unless driver
      modules = driver.fetch("modules", [])
      modules.map { |m| Driver.new(*m) }
    end

    # Determines whether the hardware is available (plugged)
    #
    # If the hardware layer was able to get its type, it consider the hardware to be connected. Bear
    # in mind that it is not possible to just rely in #exists? because it could include some info
    # from udev rules.
    #
    # @return [Boolean]
    def present?
      !!type
    end

    # Returns the MAC adress
    #
    # It usually returns the permanent MAC address (defined in the firmware).  However, when
    # missing, it will use the current MAC. See bsc#1136929 and bsc#1149234 for the reasons
    # behind preferring the permanent MAC address.
    #
    # @return [String,nil] MAC address
    def mac
      return permanent_mac unless permanent_mac.nil? || permanent_mac.empty?
      used_mac
    end

    # MAC address which is being used by the device
    #
    # @return [String,nil] MAC address
    def used_mac
      @hwinfo["mac"]
    end

    # Determines whether two objects are equivalent
    #
    # Ignores any element having a nil value.
    #
    # @param other [Hwinfo] Object to compare with
    # @return [Boolean]
    def ==(other)
      hwinfo.compact == other.hwinfo.compact
    end

    alias_method :eql?, :==
  end
end
