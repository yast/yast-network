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

    def ValidateBridge(key, event)
      old_name = NetworkInterfaces.Name
      valid = true
      confirmed = false
      items = Convert.convert(
        UI.QueryWidget(Id(key), :Items),
        :from => "any",
        :to   => "list <term>"
      )
      sel = UI.QueryWidget(Id("BRIDGE_PORTS"), :SelectedItems)
      confs = []
      configurations = NetworkInterfaces.FilterDevices("netcard")
      Builtins.foreach(
        Builtins.splitstring(
          NetworkInterfaces.CardRegex["netcard"] || "",
          "|"
        )
      ) do |devtype|
        confs = Builtins.union(
          confs,
          Map.Keys(configurations[devtype] || {})
        )
      end
      sel.each do |device|
          if confs.include?(device)
            # allow to add bonding device into bridge and also device with mask /32(bnc#405343)
            dev_type = NetworkInterfaces.GetType(device)
            case dev_type
              when "tap"
                next

              when "bond"
                if LanItems.operation == :add
                  NetworkInterfaces.Edit(device)
                  NetworkInterfaces.Current["IPADDR"] = "0.0.0.0"
                  NetworkInterfaces.Current["NETMASK"] = "255.255.255.255"
                  NetworkInterfaces.Current["BOOTPROTO"] = "static"
                  NetworkInterfaces.Commit
                  NetworkInterfaces.Add
                end
                next
            end

            ifcfg_conf = configurations[dev_type][device]
            if (ifcfg_conf["PREFIXLEN"] || "") != "32" ||
               (ifcfg_conf["NETMASK"] || "") != "255.255.255.255"
              if (ifcfg_conf["IPADDR"] || "") != "0.0.0.0" &&
                 (ifcfg_conf["BOOTPROTO"] || "") != "none"
                if !confirmed
                  valid = Popup.ContinueCancel(
                    _(
                      "At least one selected device is already configured.\nAdapt the configuration for bridge?\n"
                    )
                  )
                  confirmed = true
                end
                if valid
                  i = LanItems.current
                  if LanItems.FindAndSelect(device)
                    log.info("Adapt device #{device} for bridge (0.0.0.0/32)")
                    NetworkInterfaces.Edit(device)
                    NetworkInterfaces.Current["IPADDR"] = "0.0.0.0"
                    NetworkInterfaces.Current["PREFIXLEN"] = "32"
                    NetworkInterfaces.Current["BOOTPROTO"] = "static"
                    NetworkInterfaces.Commit
                    NetworkInterfaces.Add
                    LanItems.current = i
                  end
                end
              end
            end
          end
      end
      NetworkInterfaces.Select(old_name)
      valid
    end
  end
end
