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
      sel = Convert.convert(
        UI.QueryWidget(Id("BRIDGE_PORTS"), :SelectedItems),
        :from => "any",
        :to   => "list <string>"
      )
      confs = []
      configurations = NetworkInterfaces.FilterDevices("netcard")
      Builtins.foreach(
        Builtins.splitstring(
          Ops.get(NetworkInterfaces.CardRegex, "netcard", ""),
          "|"
        )
      ) do |devtype|
        confs = Convert.convert(
          Builtins.union(
            confs,
            Map.Keys(Ops.get_map(configurations, devtype, {}))
          ),
          :from => "list",
          :to   => "list <string>"
        )
      end
      Builtins.foreach(items) do |t|
        device = Ops.get_string(t, [0, 0], "")
        if Builtins.contains(sel, device) && IsNotEmpty(device)
          if Builtins.contains(confs, device)
            # allow to add bonding device into bridge and also device with mask /32(bnc#405343)
            if Builtins.contains(
                ["tun", "tap"],
                NetworkInterfaces.GetType(device)
              )
              next
            end
            if Builtins.contains(["bond"], NetworkInterfaces.GetType(device))
              if LanItems.operation == :add
                old_name2 = NetworkInterfaces.Name
                NetworkInterfaces.Edit(device)
                Ops.set(NetworkInterfaces.Current, "IPADDR", "0.0.0.0")
                Ops.set(NetworkInterfaces.Current, "NETMASK", "255.255.255.255")
                Ops.set(NetworkInterfaces.Current, "BOOTPROTO", "static")
                NetworkInterfaces.Commit
                NetworkInterfaces.Add
              end
              next
            end
            if Ops.get_string(
                configurations,
                [NetworkInterfaces.GetType(device), device, "PREFIXLEN"],
                ""
              ) != "32" ||
                Ops.get_string(
                  configurations,
                  [NetworkInterfaces.GetType(device), device, "NETMASK"],
                  ""
                ) != "255.255.255.255"
              if Ops.get_string(
                  configurations,
                  [NetworkInterfaces.GetType(device), device, "IPADDR"],
                  ""
                ) != "0.0.0.0" &&
                  Ops.get_string(
                    configurations,
                    [NetworkInterfaces.GetType(device), device, "BOOTPROTO"],
                    ""
                  ) != "none"
                if !confirmed
                  valid = Popup.ContinueCancel(
                    _(
                      "At least one selected device is already configured.\nAdapt the configuration for bridge (IP address 0.0.0.0/32)?\n"
                    )
                  )
                  confirmed = true
                end
                if valid
                  i = LanItems.current
                  if LanItems.FindAndSelect(device)
                    Builtins.y2internal(
                      "Adapt device %1 for bridge (0.0.0.0/32)",
                      device
                    )
                    NetworkInterfaces.Edit(device)
                    Ops.set(NetworkInterfaces.Current, "IPADDR", "0.0.0.0")
                    Ops.set(NetworkInterfaces.Current, "PREFIXLEN", "32")
                    Ops.set(NetworkInterfaces.Current, "BOOTPROTO", "static")
                    NetworkInterfaces.Commit
                    NetworkInterfaces.Add
                    LanItems.current = i
                  end
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
