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
require "y2network/interface_defaults"

module Y2Network
  # Stores what's needed when creating a new configuration for an interface
  #
  # FIXME: it should be in charge of generating reasonable defaults too
  #        @see LanItems::new_item_default_options & co
  class InterfaceConfigBuilder
    # @return [String] Device name (eth0, wlan0, etc.)
    attr_accessor :name
    # @return [String] type which is intended to be build
    attr_accessor :type

    include Y2Network::InterfaceDefaults

    # Constructor
    #
    # Load with reasonable defaults;
    # see LanItems::new_item_default_options, LanItems::@SysconfigDefaults and
    # others as in LanItems::Select
    def initialize
      @config = init_device_config({})
      @s390_config = init_device_s390_config({})
    end

    # Stores one option value tuple
    def set(option: nil, value: nil)
      # TODO: guards on option / value
      # TODO: we can validate if the option is reasonable for given type
      # TODO: may be that pushing should be rejected until the type is known
      @config[option] = value
    end

    # Returns currently stored option value
    def option(option)
      @config.fetch(option, "")
    end

    # Provides stored configuration in sysconfig format
    #
    # @return [Hash<String, String>] where key is sysconfig option and value is the option's value
    def device_sysconfig
      # with naive implementation of filtering options by type
      config = @config

      config = config.delete_if { |k, _| k =~ /WIRELESS.*/ } if type != "wlan"
      config = config.delete_if { |k, _| k =~ /BONDING.*/ } if type != "bond"
      config = config.delete_if { |k, _| k =~ /BRIDGE.*/ } if type != "br"
      config = config.delete_if { |k, _| k =~ /TUNNEL.*/ } if !["tun", "tap"].include?(type)
      config = config.delete_if { |k, _| k == "VLAN_ID" || k == "ETHERDEVICE" } if type != "vlan"
      config = config.delete_if { |k, _| k == "IPOIB_MODE" } if type != "ib"
      config = config.delete_if { |k, _| k == "INTERFACE" } if type != "dummy"

      # initalize options which has to be known and was not set by the user explicitly
      init_mandatory_options

      config
    end

    # Updates itself according to the given sysconfig configuration
    #
    # @param [Hash<String, String>] a key, value map where key is sysconfig option
    #                               and corresponding value is the option value
    def load_sysconfig(devmap)
      @config = !devmap.nil? ? @config.merge(devmap) : @config
    end

    def load_s390_config(devmap)
      @s390_config = !devmap.nil? ? @s390_config.merge(devmap) : @s390_config
    end

  private

    # returns a map with device options for newly created item
    def init_mandatory_options
      # FIXME: NetHwDetection is done in Lan.Read
      Yast.import "NetHwDetection"

      # #104494 - always write IPADDR+NETMASK, even empty
      # #50955 omit computable fields
      config["BROADCAST"] = ""
      config["NETWORK"] = ""

      if !config["NETMASK"] || config["NETMASK"].empty?
        config["NETMASK"] = Yast::NetHwDetection.result["NETMASK"] || "255.255.255.0"
      end
      if !config["STARTMODE"] || config["STARTMODE"].empty?
        config["STARTMODE"] = new_device_startmode
      end
      if !config["DHCLIENT_SET_DEFAULT_ROUTE"] || config["DHCLIENT_SET_DEFAULT_ROUTE"].empty?
        config["DHCLIENT_SET_DEFAULT_ROUTE"] = "no"
      end
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
          hotplug_usable? ? "hotplug" : "auto"
        else
          product_startmode
        end
      when "auto"
        "auto"
      else
        hotplug_usable? ? "hotplug" : "auto"
      end

      startmode
    end

    def replace_ifplugd?
      Yast.import "Arch"
      Yast.import "NetworkService"

      return true if !Yast::Arch.is_laptop
      return true if Yast::NetworkService.is_network_manager
      return true if ["bond", "vlan", "br"].include? type

      false
    end

    def hotplug_usable?
      Hwinfo.new(name).hotplug
    end
  end
end
