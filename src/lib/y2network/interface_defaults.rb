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
require "yaml"

module Y2Network
  module InterfaceDefaults

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

    # returns a map with device options for newly created item
    def new_item_default_options
      # FIXME: NetHwDetection is done in Lan.Read
      Yast.import "NetHwDetection"

      {
        # bnc#46369
        "NETMASK"                    => Yast::NetHwDetection.result["NETMASK"] || "255.255.255.0",
        "STARTMODE"                  => new_device_startmode,
        # bnc#883836 bnc#868187
        "DHCLIENT_SET_DEFAULT_ROUTE" => "no"
      }
    end

    # Initialiates device configuration map with default values when needed
    #
    # @param devmap [Hash<String, String>] current device configuration
    #
    # @return device configuration map where unspecified values were set
    #                to reasonable defaults
    def init_device_config(devmap)
      Yast.import "Arch"

      # the defaults here are what sysconfig defaults to
      # (as opposed to what a new interface gets, in {#Select)}
      defaults = YAML.load_file(Yast::Directory.find_data_file("network/sysconfig_defaults.yml"))
      defaults.merge(devmap)
    end

    def init_device_s390_config(devmap)
      return {} if !Yast::Arch.s390

      # Default values used when creating an emulated NIC for physical s390 hardware.
      s390_defaults = YAML.load_file(Directory.find_data_file("network/s390_defaults.yml")) if Arch.s390
      s390_defaults.merge(devmap)
    end
  end
end
