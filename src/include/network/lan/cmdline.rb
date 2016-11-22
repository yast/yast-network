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
# File:	lan/cmdline.ycp
# Package:	Network configuration
# Summary:	Network cards cmdline handlers
# Authors:	Michal Svec <msvec@suse.cz>
#
module Yast
  module NetworkLanCmdlineInclude
    def initialize_network_lan_cmdline(_include_target)
      textdomain "network"

      Yast.import "CommandLine"
      Yast.import "Label"
      Yast.import "Lan"
      Yast.import "NetworkInterfaces"
      Yast.import "RichText"
      Yast.import "Report"
      Yast.import "LanItems"
      Yast.import "Map"
    end

    def getConfigList(config_filter)
      confList = []
      count = -1
      LanItems.BuildLanOverview
      # list<map<string,any> > overview = (list<map<string,any> >)LanItems::Overview();
      Builtins.foreach(LanItems.Items) do |position, _row|
        LanItems.current = position
        count = Ops.add(count, 1)
        if Ops.greater_than(
          Builtins.size(Ops.get_string(LanItems.getCurrentItem, "ifcfg", "")),
          0
        )
          next if config_filter == "unconfigured"
        elsif config_filter == "configured"
          next
        end
        confList = Builtins.add(
          confList,
          Builtins.tostring(count) => {
            "id"         => position,
            "rich_descr" => Ops.get_string(
              LanItems.getCurrentItem,
              ["table_descr", "rich_descr"],
              ""
            ),
            "descr"      => Ops.get_string(
              LanItems.getCurrentItem,
              ["table_descr", "table_descr", 0],
              ""
            ),
            "addr"       => Ops.get_string(
              LanItems.getCurrentItem,
              ["table_descr", "table_descr", 1],
              ""
            )
          }
        )
      end
      deep_copy(confList)
    end

    def validateId(options, config)
      if !options["id"]
        Report.Error(_("Use \"id\" option to determine device."))
        return false
      end

      begin
        id = Integer(options["id"])
      rescue ArgumentError
        Report.Error(_("Invalid value '%s' for \"id\" option.") % options["id"])
        return false
      end

      if id >= config.size
        Report.Error(
          _("Value of \"id\" is out of range. Use \"list\" option to check max. value of \"id\".")
        )
        return false
      end
      true
    end

    def getItem(options, config)
      options = deep_copy(options)
      config = deep_copy(config)
      ret = -1
      Builtins.foreach(config) do |row|
        if Ops.get(options, "id", "0") == Ops.get_string(Map.Keys(row), 0, "")
          ret = Builtins.tointeger(Ops.get_string(Map.Keys(row), 0, "-1"))
        end
      end
      Builtins.y2error("Device not matched!") if ret == -1
      ret
    end

    # Handler for action "show"
    # @param [Hash{String => String}] options action options
    def ShowHandler(options)
      options = deep_copy(options)
      config = getConfigList("")
      return false if validateId(options, config) == false
      Builtins.foreach(config) do |row|
        Builtins.foreach(
          Convert.convert(
            row,
            from: "map <string, any>",
            to:   "map <string, map <string, any>>"
          )
        ) do |key, value|
          if key == Ops.get(options, "id", "0")
            # create plain text from formated HTML
            text = Builtins.sformat(
              "echo \"%1\"|sed s/'<br>'/'\\n'/g|sed s/'<\\/li>'/'\\n'/g|sed s/'<[/a-z]*>'/''/g",
              Ops.get_string(value, "rich_descr", "")
            )
            descr = Convert.convert(
              SCR.Execute(path(".target.bash_output"), text),
              from: "any",
              to:   "map <string, any>"
            )
            CommandLine.Print(Ops.get_string(descr, "stdout", ""))
          end
        end
      end
      true
    end

    def ListHandler(options)
      options = deep_copy(options)
      config_filter = ""
      if Builtins.contains(Map.Keys(options), "configured")
        config_filter = "configured"
      end
      if Builtins.contains(Map.Keys(options), "unconfigured")
        config_filter = "unconfigured"
      end
      confList = getConfigList(config_filter)
      if Ops.greater_than(Builtins.size(confList), 0)
        CommandLine.Print("id\tname, \t\t\tbootproto")
      end
      Builtins.foreach(confList) do |row|
        Builtins.foreach(
          Convert.convert(
            row,
            from: "map <string, any>",
            to:   "map <string, map <string, any>>"
          )
        ) do |id, detail|
          CommandLine.Print(
            Builtins.sformat(
              "%1\t%2, %3",
              id,
              Ops.get_string(detail, "descr", ""),
              Ops.get_string(detail, "addr", "")
            )
          )
        end
      end
      true
    end

    # Handler for action "add"
    # @param [Hash{String => String}] options action options
    def AddHandler(options)
      options = deep_copy(options)
      LanItems.AddNew
      Lan.Add
      Ops.set(
        LanItems.Items,
        [LanItems.current, "ifcfg"],
        Ops.get(options, "name", "")
      )
      LanItems.type = NetworkInterfaces.device_type(
        Ops.get(options, "name", "")
      )
      if LanItems.type == "bond"
        LanItems.bond_slaves = Builtins.splitstring(
          Ops.get(options, "slaves", ""),
          " "
        )
      end
      if LanItems.type == "vlan"
        LanItems.vlan_etherdevice = Ops.get(options, "ethdevice", "")
      end
      if LanItems.type == "br"
        LanItems.bridge_ports = Ops.get(options, "bridge_ports", "")
      end

      LanItems.bootproto = Ops.get(options, "bootproto", "none")
      if !Builtins.contains(["none", "static", "dhcp"], LanItems.bootproto)
        Report.Error(_("Impossible value for bootproto."))
        return false
      end

      LanItems.ipaddr = Ops.get(options, "ip", "")
      LanItems.prefix = Ops.get(options, "prefix", "")
      LanItems.netmask = Ops.get(options, "netmask", "255.255.255.0")
      LanItems.startmode = Ops.get(options, "startmode", "auto")
      if !Builtins.contains(["auto", "ifplugd", "nfsroot"], LanItems.startmode)
        Report.Error(_("Impossible value for startmode."))
        return false
      end

      LanItems.Commit
      ListHandler({})

      true
    end

    # Handler for action "edit"
    # @param [Hash{String => String}] options action options
    def EditHandler(options)
      options = deep_copy(options)
      config = getConfigList("")

      return false if validateId(options, config) == false

      LanItems.current = getItem(options, config)
      LanItems.SetItem

      if Builtins.size(Ops.get_string(LanItems.getCurrentItem, "ifcfg", "")) == 0
        NetworkInterfaces.Add
        LanItems.operation = :edit
        interfacename = Ops.get_string(
          LanItems.getCurrentItem,
          ["hwinfo", "dev_name"],
          ""
        )
        Ops.set(
          LanItems.Items,
          [LanItems.current, "ifcfg"],
          interfacename
        )
      end

      if Builtins.contains(Map.Keys(options), "ip")
        Ops.set(options, "bootproto", "static")
      end

      LanItems.bootproto = Ops.get(options, "bootproto", "none")
      if !Builtins.contains(["none", "static", "dhcp"], LanItems.bootproto)
        Report.Error(_("Impossible value for bootproto."))
        return false
      end
      if LanItems.bootproto == "static"
        if !Ops.greater_than(Builtins.size(Ops.get(options, "ip", "")), 0)
          Report.Error(
            _("For static configuration, the \"ip\" option is needed.")
          )
          return false
        end
        LanItems.ipaddr = Ops.get(options, "ip", "")
        if Ops.greater_than(Builtins.size(Ops.get(options, "prefix", "")), 0)
          LanItems.prefix = Ops.get(options, "prefix", "")
        else
          LanItems.netmask = Ops.get(options, "netmask", "255.255.255.0")
          LanItems.prefix = ""
        end
      else
        LanItems.ipaddr = ""
        LanItems.netmask = ""
      end

      LanItems.startmode = Ops.get(options, "startmode", "auto")
      if !Builtins.contains(["auto", "ifplugd", "nfsroot"], LanItems.startmode)
        Report.Error(_("Impossible value for startmode."))
        return false
      end

      LanItems.Commit
      ShowHandler(options)
      true
    end

    # Handler for action "delete"
    # @param [Hash{String => String}] options action options
    def DeleteHandler(options)
      options = deep_copy(options)
      config = getConfigList("")
      return false if validateId(options, config) == false
      Builtins.foreach(config) do |row|
        Builtins.foreach(
          Convert.convert(
            row,
            from: "map <string, any>",
            to:   "map <string, map <string, any>>"
          )
        ) do |key, value|
          if key == Ops.get(options, "id", "0")
            LanItems.current = Builtins.tointeger(
              Ops.get_integer(value, "id", -1)
            )
            Lan.Delete
            CommandLine.Print(_("The device was deleted."))
          end
        end
      end

      true
    end
  end
end
