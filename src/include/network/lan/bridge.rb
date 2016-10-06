# encoding: utf-8

# ***************************************************************************
#
# Copyright (c) 2012 Novell, Inc.
# All Rights Reserved.
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of version 2 of the GNU General Public License as
# published by the Free Software Foundation.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.   See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, contact Novell, Inc.
#
# To contact Novell about this file by physical or electronic mail,
# you may find current contact information at www.novell.com
#
# **************************************************************************
# File:	include/network/lan/address.ycp
# Package:	Network configuration
# Summary:	Network card adresss configuration dialogs
# Authors:	Michal Svec <msvec@suse.cz>
#
module Yast
  module NetworkLanBridgeInclude
    include Logger

    def initialize_network_lan_bridge(_include_target)
      textdomain "network"
    end

    # Checks if the given interface is using the old way of config enslaved
    # interfaces with bootproto as static and 0.0.0.0 as IPADDR
    #
    # @param [String] interface name
    # @return [Boolean] returns true if given enslaved interface is configured
    # in the old way
    def old_bridge_port_config?(ifcfg_name)
      devmap = LanItems.GetDeviceMap(LanItems.find_configured(ifcfg_name))
      return false unless devmap

      devmap["BOOTPROTO"] == "static" && devmap["IPADDR"] == "0.0.0.0"
    end

    # Immediately updates device's ifcfg to be usable as bridge port.
    #
    # It mainly setups suitable BOOTPROTO an IP related values
    def configure_as_bridge_port(device)
      selected_interface = NetworkInterfaces.Current
      log.info("Adapt device #{device} as bridge port")

      # when using wicked every device which can be bridged
      # can be set to BOOTPROTO=none. No workaround with
      # BOOTPROTO=static required anymore
      if NetworkInterfaces.Edit(device)
        NetworkInterfaces.Current["IPADDR"] = ""
        NetworkInterfaces.Current["NETMASK"] = ""
        NetworkInterfaces.Current["BOOTPROTO"] = "none"
        # take out PREFIXLEN from old configuration (BNC#735109)
        NetworkInterfaces.Current["PREFIXLEN"] = ""

        # remove all aliases (bnc#590167)
        aliases = NetworkInterfaces.Current["_aliases"] || {}
        aliases.each do |alias_name, alias_ip|
          NetworkInterfaces.DeleteAlias(device, alias_name) if alias_ip
        end
        NetworkInterfaces.Current["_aliases"] = {}

        NetworkInterfaces.Commit
        NetworkInterfaces.Add

        NetworkInterfaces.Current = selected_interface
      end

      Lan.autoconf_slaves += [device] unless Lan.autoconf_slaves.include? device

      true
    end

    # Asks the user about adapt the current bridge port config in case that it
    # is configured in the old way (BOOTPROTO == static) & (IPADDR == 0.0.0.0).
    def adapt_bridge_port_config?(ports)
      return false if ports.nil? || ports.empty?

      Popup.YesNoHeadline(
        Label.WarningMsg,
        format(_("The bridge ports listed below are configured in the old way.\n\n" \
                 "Bridge ports: %s\n\n" \
                 "Do you want to adapt them now?"), ports.join(", "))
      )
    end

    # Adapts the configuration of the given port from the old way (previous of
    # SLE12) to the new one. (bsc#962824)
    #
    # @param [String] Bridge port to be adapted
    # @return [Boolean] true if the device map is obtained and modified
    def adapt_bridge_port_config!(port)
      item_id = LanItems.find_configured(port)
      devmap = LanItems.GetDeviceMap(item_id)

      return false unless devmap

      devmap["IPADDR"] = ""
      devmap["NETMASK"] = ""
      devmap["BOOTPROTO"] = "none"
      # take out PREFIXLEN from old configuration (BNC#735109)
      devmap["PREFIXLEN"] = ""

      LanItems.SetDeviceMap(item_id, devmap)

      true
    end

    def ValidateBridge(_key, _event)
      sel = UI.QueryWidget(Id("BRIDGE_PORTS"), :SelectedItems)

      configurations = NetworkInterfaces.FilterDevices("netcard")
      netcard_types = (NetworkInterfaces.CardRegex["netcard"] || "").split("|")

      confs = netcard_types.reduce([]) do |res, devtype|
        res.concat((configurations[devtype] || {}).keys)
      end

      valid = true

      sel.each do |device|
        next if !confs.include?(device)

        dev_type = NetworkInterfaces.GetType(device)
        ifcfg_conf = configurations[dev_type][device]

        next if ifcfg_conf["BOOTPROTO"] == "none"

        valid = Popup.ContinueCancel(
          _(
            "At least one selected device is already configured.\nAdapt the configuration for bridge?\n"
          )
        )
        break
      end
      valid
    end
  end
end
