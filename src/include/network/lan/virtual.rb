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
  module NetworkLanVirtualInclude
    def initialize_network_lan_virtual(include_target)
      textdomain "network"

      Yast.import "IP"
      Yast.import "Label"
      Yast.import "Lan"
      Yast.import "Netmask"
      Yast.import "NetworkInterfaces"
      Yast.import "NetworkService"
      Yast.import "Popup"
      Yast.import "Report"
      Yast.import "Wizard"
      Yast.import "String"

      Yast.include include_target, "network/routines.rb"
    end

    def initAdditional(_key)
      # #165059
      if NetworkService.is_network_manager
        UI.ChangeWidget(:f_additional, :Enabled, false)
      end

      table_items = []
      # make ui items from the aliases list
      Builtins.maplist(
        Convert.convert(
          LanItems.aliases,
          from: "map",
          to:   "map <string, map>"
        )
      ) do |_alias, data|
        label = Ops.get_string(data, "LABEL", "")
        ip = Ops.get_string(data, "IPADDR", "")
        mask = Ops.get_string(data, "NETMASK", "")
        if Ops.greater_than(
          Builtins.size(Ops.get_string(data, "PREFIXLEN", "")),
          0
          )
          mask = Builtins.sformat("/%1", Ops.get_string(data, "PREFIXLEN", ""))
        end
        table_items = Builtins.add(
          table_items,
          Item(Id(Builtins.size(table_items)), label, ip, mask)
        )
      end

      UI.ChangeWidget(Id(:table), :Items, table_items)

      nil
    end

    # Main aliases dialog
    # @param standalone true if not run from another ycp client
    # @return dialog result
    def handleAdditional(_key, event)
      event = deep_copy(event)
      return nil if NetworkService.is_network_manager

      table_items = Convert.convert(
        UI.QueryWidget(Id(:table), :Items),
        from: "any",
        to:   "list <term>"
      )

      if Ops.get_string(event, "EventReason", "") == "Activated"
        cur = Convert.to_integer(UI.QueryWidget(Id(:table), :CurrentItem))
        case Ops.get_symbol(event, "ID", :nil)
        when :edit
          @item = VirtualEditDialog(cur, Ops.get(table_items, cur))
          if !@item.nil?
            Ops.set(table_items, cur, @item)
            UI.ChangeWidget(Id(:table), :Items, table_items)
            UI.ChangeWidget(Id(:table), :CurrentItem, cur)
          end
        when :add
          @item2 = VirtualEditDialog(
            Builtins.size(table_items),
            term(:empty)
          )
          Builtins.y2debug("item=%1", @item2)
          if !@item2.nil?
            table_items = Builtins.add(table_items, @item2)
            UI.ChangeWidget(Id(:table), :Items, table_items)
            UI.ChangeWidget(
              Id(:table),
              :CurrentItem,
              Builtins.size(table_items)
            )
          end
        when :delete
          table_items = Builtins.filter(table_items) do |e|
            cur != Ops.get(e, [0, 0])
          end
          UI.ChangeWidget(Id(:table), :Items, table_items)
        end
      end

      UI.ChangeWidget(
        Id(:edit),
        :Enabled,
        Ops.greater_than(Builtins.size(table_items), 0)
      )
      UI.ChangeWidget(
        Id(:delete),
        :Enabled,
        Ops.greater_than(Builtins.size(table_items), 0)
      )

      nil
    end

    def storeAdditional(_key, _event)
      if !NetworkService.is_network_manager
        table_items = Convert.convert(
          UI.QueryWidget(Id(:table), :Items),
          from: "any",
          to:   "list <term>"
        )
        aliases_to_delete = deep_copy(LanItems.aliases) # #48191
        LanItems.aliases = {}
        Builtins.maplist(table_items) do |e|
          alias_ = {}
          Ops.set(alias_, "IPADDR", Ops.get_string(e, 2, ""))
          if Ops.greater_than(Builtins.size(Ops.get_string(e, 1, "")), 0)
            Ops.set(alias_, "LABEL", Ops.get_string(e, 1, ""))
          end
          if Builtins.substring(Ops.get_string(e, 3, ""), 0, 1) == "/"
            Ops.set(
              alias_,
              "PREFIXLEN",
              Builtins.substring(Ops.get_string(e, 3, ""), 1)
            )
          else
            if Netmask.Check6(Ops.get_string(e, 3, ""))
              Ops.set(alias_, "PREFIXLEN", Ops.get_string(e, 3, ""))
            else
              Ops.set(alias_, "NETMASK", Ops.get_string(e, 3, ""))
            end
          end
          Ops.set(
            LanItems.aliases,
            Builtins.tostring(Builtins.size(LanItems.aliases)),
            alias_
          )
        end
        Builtins.foreach(
          Convert.convert(
            aliases_to_delete,
            from: "map",
            to:   "map <string, any>"
          )
        ) do |a, v|
          NetworkInterfaces.DeleteAlias(NetworkInterfaces.Name, a) if !v.nil?
        end
      end

      nil
    end

    # max length of device / interface filename lenght supported by kernel
    IFACE_LABEL_MAX = 16

    # Open a dialog to edit a name-ipaddr-netmask triple.
    # @param id    [Integer]    an id for the table item to be returned
    # @param entry [Yast::Term] an existing entry to be edited, or term(:empty)
    # @return      [Yast::Term] a table item for OK, nil for Cancel
    def VirtualEditDialog(id, entry)
      entry = deep_copy(entry)
      Builtins.y2debug("id=%1", id)
      Builtins.y2debug("entry=%1", entry)

      UI.OpenDialog(
        Opt(:decorated),
        VBox(
          HSpacing(1),
          VBox(
            # TextEntry label
            TextEntry(Id(:name), _("IPv4 &Address Label"), Ops.get_string(entry, 1, "")),
            # TextEntry label
            TextEntry(
              Id(:ipaddr),
              _("&IP Address"),
              Ops.get_string(entry, 2, "")
            ),
            # TextEntry label
            TextEntry(Id(:netmask), _("Net&mask"), Ops.get_string(entry, 3, ""))
          ),
          HSpacing(1),
          HBox(
            PushButton(Id(:ok), Opt(:default), Label.OKButton),
            PushButton(Id(:cancel), Label.CancelButton)
          )
        )
      )

      UI.ChangeWidget(
        Id(:name),
        :ValidChars,
        String.CAlnum
      )
      UI.ChangeWidget(Id(:ipaddr), :ValidChars, IP.ValidChars)

      if entry == term(:empty)
        UI.SetFocus(Id(:name))
      else
        UI.SetFocus(Id(:ipaddr))
      end

      while (ret = UI.UserInput) == :ok

        host = Item(Id(id))
        val = UI.QueryWidget(Id(:name), :Value)

        if LanItems.device.size + val.size + 1 > IFACE_LABEL_MAX
          # Popup::Error text
          Popup.Error(_("Label is too long."))
          UI.SetFocus(Id(:name))
          next
        end

        host = Builtins.add(host, val)

        ip = UI.QueryWidget(Id(:ipaddr), :Value)
        if !IP.Check(ip)
          # Popup::Error text
          Popup.Error(_("The IP address is invalid."))
          UI.SetFocus(Id(:ipaddr))
          next
        end
        host = Builtins.add(host, ip)

        val = UI.QueryWidget(Id(:netmask), :Value)
        if !validPrefixOrNetmask(ip, val)
          # Popup::Error text
          Popup.Error(_("The subnet mask is invalid."))
          UI.SetFocus(Id(:netmask))
          next
        end
        host = Builtins.add(host, val)

        break
      end

      UI.CloseDialog
      return nil if ret != :ok

      deep_copy(host)
    end
  end
end
