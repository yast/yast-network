# encoding: utf-8

#***************************************************************************
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
#**************************************************************************
# File:	include/network/lan/address.ycp
# Package:	Network configuration
# Summary:	Network card adresss configuration dialogs
# Authors:	Michal Svec <msvec@suse.cz>
#
module Yast
  module NetworkLanBridgeInclude
    include Logger

    def initialize_network_lan_bridge(include_target)
      textdomain "network"
    end

    # Initializes widget (BRIDGE_PORTS) which contains list of devices available
    # for enslaving in a brige.
    #
    # @param [String] key	id of the widget
    def InitBridge(key)
      br_ports = Builtins.splitstring(
        Ops.get_string(NetworkInterfaces.Current, "BRIDGE_PORTS", ""),
        " "
      )
      items = CreateSlaveItems(
        LanItems.GetBridgeableInterfaces(LanItems.GetCurrentName),
        br_ports
      )

      UI.ChangeWidget(Id(key), :Items, items)

      nil
    end

    def configure_as_bridge_port(device)
      log.info("Adapt device #{device} as bridge port")

      # when using wicked every device which can be bridged
      # can be set to BOOTPROTO=none. No workaround with
      # BOOTPROTO=static required anymore
      NetworkInterfaces.Edit(device)
      NetworkInterfaces.Current["IPADDR"] = ""
      NetworkInterfaces.Current["NETMASK"] = ""
      NetworkInterfaces.Current["BOOTPROTO"] = "none"
      NetworkInterfaces.Commit
      NetworkInterfaces.Add
    end

    def ValidateBridge(key, event)
      sel = UI.QueryWidget(Id("BRIDGE_PORTS"), :SelectedItems)

      configurations = NetworkInterfaces.FilterDevices("netcard")
      netcard_types = (NetworkInterfaces.CardRegex["netcard"] || "").split("|")

      confs = netcard_types.reduce([]) do |res, devtype|
        res.concat((configurations[devtype] || {}).keys)
      end

      valid = true
      confirmed = false

      sel.each do |device|
        next if !confs.include?(device)

        dev_type = NetworkInterfaces.GetType(device)
        ifcfg_conf = configurations[dev_type][device]

        if ifcfg_conf["BOOTPROTO"] != "none" && !confirmed
            valid = Popup.ContinueCancel(
              _(
                "At least one selected device is already configured.\nAdapt the configuration for bridge?\n"
              )
            )
            confirmed = true
        end
      end
      valid
    end
  end
end
