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

Yast.import "LanItems"
Yast.import "NetworkInterfaces"

module Y2Network
  # Collects data from the UI until we have enough of it to create a {Y2Network::Interface}.
  # {Yast::LanItemsClass#Commit Yast::LanItems.Commit(builder)} uses it.
  class InterfaceConfigBuilder
    # @return [String] Device name (eth0, wlan0, etc.)
    attr_accessor :name
    # @return [String] type of @see Y2Network::Interface which is intended to be build (e.g. "eth")
    attr_accessor :type

    # Constructor
    #
    # Load with reasonable defaults
    def initialize
      @config = init_device_config({})
      @s390_config = init_device_s390_config({})
    end

    def newly_added?
      Yast::LanItems.operation == :add
    end

    def []=(key, value)
      @config[key] = value
    end

    def [](key)
      @config[key]
    end

    def save
      Yast::LanItems.setDriver(driver)
      Yast::LanItems.driver_options[driver] = driver_options
    end

    # how many device names is proposed
    NEW_DEVICES_COUNT = 10
    # Propose bunch of possible names for interface
    # do not modify anything
    # @return [Array<String>]
    def proposed_names
      Yast::LanItems.new_type_devices(type, NEW_DEVICES_COUNT)
    end

    def valid_name?(name)
      !!(name =~ /^[[:alnum:]._:-]{1,15}\z/)
    end

    def name_exists?(name)
      Yast::NetworkInterfaces.List("").include?(name)
    end

    def name_valid_characters
      Yast::NetworkInterfaces.ValidCharsIfcfg
    end

    def kernel_modules
      Yast::LanItems.GetItemModules("")
    end

    def driver
      @driver ||= Yast::Ops.get_string(Yast::LanItems.getCurrentItem, ["udev", "driver"], "")
    end

    def driver=(value)
      @driver = value
    end

    def driver_options
      target_driver = @driver
      target_driver = hwinfo.module if target_driver.empty?
      @driver_options ||= Yast::LanItems.driver_options[target_driver] || ""
    end

    def driver_options=(value)
      @driver_options = value
    end

    # Provides stored configuration in sysconfig format
    #
    # @return [Hash<String, String>] where key is sysconfig option and value is the option's value
    def device_sysconfig
      # with naive implementation of filtering options by type
      config = @config

      # initalize options which has to be known and was not set by the user explicitly
      init_mandatory_options

      # filter out options which are not needed
      config = config.delete_if { |k, _| k =~ /WIRELESS.*/ } if type != "wlan"
      config = config.delete_if { |k, _| k =~ /BONDING.*/ } if type != "bond"
      config = config.delete_if { |k, _| k =~ /BRIDGE.*/ } if type != "br"
      config = config.delete_if { |k, _| k =~ /TUNNEL.*/ } if !["tun", "tap"].include?(type)
      config = config.delete_if { |k, _| k == "VLAN_ID" || k == "ETHERDEVICE" } if type != "vlan"
      config = config.delete_if { |k, _| k == "IPOIB_MODE" } if type != "ib"
      config = config.delete_if { |k, _| k == "INTERFACE" } if type != "dummy"
      config = config.delete_if { |k, _| k == "IFPLUGD_PRIORITY" } if config["STARTMODE"] != "ifplugd"

      # all keys / values has to be strings, agent won't write it otherwise
      config.map { |k, v| [k, v.to_s] }.to_h
    end

    # Updates itself according to the given sysconfig configuration
    #
    # @param devmap [Hash<String, String>, nil] a key, value map where key is sysconfig option
    #                                           and corresponding value is the option value
    def load_sysconfig(devmap)
      @config.merge!(devmap || {})
    end

    def load_s390_config(devmap)
      @s390_config.merge!(devmap || {})
    end

  private

    # Initializes device configuration map with default values when needed
    #
    # @param devmap [Hash<String, String>] current device configuration
    #
    # @return device configuration map where unspecified values were set
    #                to reasonable defaults
    def init_device_config(devmap)
      # the defaults here are what sysconfig defaults to
      # (as opposed to what a new interface gets, in {#Select)}
      defaults = YAML.load_file(Yast::Directory.find_data_file("network/sysconfig_defaults.yml"))
      defaults.merge(devmap)
    end

    def init_device_s390_config(devmap)
      Yast.import "Arch"

      return {} if !Yast::Arch.s390

      # Default values used when creating an emulated NIC for physical s390 hardware.
      s390_defaults = YAML.load_file(Directory.find_data_file("network/s390_defaults.yml"))
      s390_defaults.merge(devmap)
    end

    # returns a map with device options for newly created item
    def init_mandatory_options
      # FIXME: NetHwDetection is done in Lan.Read
      Yast.import "NetHwDetection"

      # #104494 - always write IPADDR+NETMASK, even empty
      # #50955 omit computable fields
      @config["BROADCAST"] = ""
      @config["NETWORK"] = ""

      if !@config["NETMASK"] || @config["NETMASK"].empty?
        @config["NETMASK"] = Yast::NetHwDetection.result["NETMASK"] || "255.255.255.0"
      end

      @config["STARTMODE"] = new_device_startmode if !@config["STARTMODE"] || @config["STARTMODE"].empty?
    end

    # returns default startmode for a new device
    #
    # startmode is returned according product, Arch and current device type
    def new_device_startmode
      Yast.import "ProductFeatures"

      product_startmode = Yast::ProductFeatures.GetStringFeature(
        "network",
        "startmode"
      )

      startmode = case product_startmode
      when "ifplugd"
        if replace_ifplugd?
          hotplug_interface? ? "hotplug" : "auto"
        else
          product_startmode
        end
      when "auto"
        "auto"
      else
        hotplug_interface? ? "hotplug" : "auto"
      end

      startmode
    end

    def replace_ifplugd?
      Yast.import "Arch"
      Yast.import "NetworkService"

      return true if !Yast::Arch.is_laptop
      return true if Yast::NetworkService.is_network_manager
      # virtual devices cannot expect any event from ifplugd
      return true if ["bond", "vlan", "br"].include? type

      false
    end

    def hotplug_interface?
      hwinfo.hotplug
    end

    def hwinfo
      @hwinfo ||= Hwinfo.new(name: name)
    end
  end
end
