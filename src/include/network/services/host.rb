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
# File:	include/network/services/host.ycp
# Module:	Network configuration
# Summary:	Hosts configuration dialogs
# Authors:	Michal Svec <msvec@suse.cz>
#
#
# Hosts configuration dialogs
module Yast
  module NetworkServicesHostInclude
    def initialize_network_services_host(include_target)
      Yast.import "UI"

      textdomain "network"

      Yast.import "Host"
      Yast.import "Hostname"
      Yast.import "IP"
      Yast.import "Label"
      Yast.import "Popup"
      Yast.import "Punycode"
      Yast.import "Wizard"

      Yast.include include_target, "network/routines.rb"
    end

    # Check if given host is system and present warning in this case.
    # @param [String] host host to be checked
    # @param [Boolean] delete true if the host will be deleted
    # @return true if continue
    def HostSystemPopup(host, delete)
      return true if !Builtins.contains(Host.GetSystemHosts, host)

      # Warning popup text 1/2
      text = Builtins.sformat(_("The host %1 is a system host.") + "\n", host)

      text = if delete
        # Warning popup text 2/2
        Ops.add(text, _("Really delete it?"))
      else
        # Warning popup text 2/2
        Ops.add(text, _("Really change it?"))
      end

      Popup.AnyQuestion("", text, Label.YesButton, Label.NoButton, :focus_no)
    end

    # Main hosts dialog
    # @param [Boolean] standalone true if not run from another ycp client
    # @return dialog result
    def HostsMainDialog(standalone)
      # Hosts dialog caption
      caption = _("Host Configuration")

      # Hosts dialog help 1/2
      help = _("<p>The hosts can be set up in this dialog.</p>") +
        # Hosts dialog help 2/2
        _(
          "<p>Enter a host <b>IP Address</b>, a <b>Hostname</b>, and optional\n<b>Host Aliases</b>, separated by spaces.</p>\n"
        )

      max = 0
      table_items = []
      deleted_items = []
      hosts = Host.name_map

      Builtins.y2debug("hosts=%1", hosts)

      # make ui items from the hosts list
      Builtins.maplist(hosts) do |host, names|
        if Ops.less_than(Builtins.size(names), 1)
          Builtins.y2error("Invalid host: %1, (%2)", host, names)
          next
        end
        Builtins.foreach(names) do |s|
          name = Builtins.regexpsub(s, "^([^ \t]+)[ \t]*.*$", "\\1")
          aliases = Builtins.regexpsub(s, "^[^ \t]+[ \t]*(.*)[ \t]*$", "\\1")
          item = Item(
            Id(Builtins.size(table_items)),
            host,
            Punycode.DecodeDomainName(name),
            Ops.get(Punycode.DecodePunycodes([aliases]), 0, "")
          )
          table_items = Builtins.add(table_items, item)
        end
      end
      Builtins.y2debug("table_items=%1", table_items)
      max = Builtins.size(table_items)

      # Hosts dialog contents
      contents = HBox(
        HSpacing(5),
        VBox(
          VSpacing(2),
          # Frame label
          Frame(
            _("Current Hosts"),
            HBox(
              HSpacing(3),
              VBox(
                VSpacing(1),
                Table(
                  Id(:table),
                  Opt(:notify),
                  Header(
                    # Table header label
                    _("IP Address"),
                    # Table header label
                    _("Hostnames"),
                    # Table header label
                    _("Host Aliases")
                  ),
                  []
                ),
                Left(
                  HBox(
                    # PushButton label
                    PushButton(Id(:add), _("Ad&d")),
                    # PushButton label
                    PushButton(Id(:edit), Opt(:disabled), _("&Edit")),
                    # PushButton label
                    PushButton(Id(:delete), Opt(:disabled), _("De&lete"))
                  )
                ),
                VSpacing(1)
              ),
              HSpacing(3)
            )
          ),
          VSpacing(2)
        ),
        HSpacing(5)
      )
      if standalone == true
        Wizard.SetContentsButtons(
          caption,
          contents,
          help,
          Label.CancelButton,
          Label.OKButton
        )
        Wizard.SetNextButton(:next, Label.OKButton)
        Wizard.SetAbortButton(:abort, Label.CancelButton)
        Wizard.HideBackButton
      else
        Wizard.SetContentsButtons(
          caption,
          contents,
          help,
          Label.BackButton,
          Label.OKButton
        )
      end

      UI.ChangeWidget(Id(:table), :Items, table_items)
      UI.SetFocus(Id(:table)) if Ops.greater_than(Builtins.size(table_items), 0)

      ret = nil
      loop do
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

        ret = UI.UserInput
        Builtins.y2debug("ret=%1", ret)

        # abort?
        if ret == :abort || ret == :cancel
          ReallyAbortCond(Host.GetModified) ? break : next
        # add host
        elsif ret == :add
          item = HostDialog(max, term(:empty))
          next if item.nil?
          table_items = Builtins.add(table_items, item)
          UI.ChangeWidget(Id(:table), :Items, table_items)
          UI.ChangeWidget(Id(:table), :CurrentItem, max)
          max = Ops.add(max, 1)
          Host.SetModified
          next
        # edit host
        elsif ret == :edit || ret == :table
          cur = Convert.to_integer(UI.QueryWidget(Id(:table), :CurrentItem))
          cur_item = Builtins.filter(table_items) do |e|
            cur == Ops.get(e, [0, 0])
          end

          Builtins.y2debug("cur=%1", cur)
          Builtins.y2debug("cur_item=%1", cur_item)

          olditem = Ops.get(cur_item, 0)

          next if !HostSystemPopup(Ops.get_string(olditem, 1, ""), false)
          item = HostDialog(cur, olditem)

          next if item.nil?

          table_items = Builtins.maplist(table_items) do |e|
            if cur == Ops.get_integer(e, [0, 0], -1)
              oldentry = Builtins.mergestring(
                [Ops.get_string(olditem, 2, ""), Ops.get_string(olditem, 3, "")],
                " "
              )

              Builtins.y2debug("item: %1", item)
              Builtins.y2debug("olditem: %1", olditem)
              Builtins.y2debug("oldentry: %1", oldentry)

              ip = Ops.get_string(item, 1, "")
              oldip = Ops.get_string(olditem, 1, "")

              deleted_items = Builtins.add(deleted_items, oldip) if ip != oldip
              Builtins.y2debug("Deleting: %1 (%2)", oldip, ip)

              next deep_copy(item)
            end
            deep_copy(e)
          end
          UI.ChangeWidget(Id(:table), :Items, table_items)
          UI.ChangeWidget(Id(:table), :CurrentItem, cur)
          Host.SetModified
          next
        # delete host
        elsif ret == :delete
          cur = Convert.to_integer(UI.QueryWidget(Id(:table), :CurrentItem))
          cur_item = Builtins.filter(table_items) do |e|
            cur == Ops.get(e, [0, 0])
          end

          Builtins.y2debug("cur=%1", cur)
          Builtins.y2debug("cur_item=%1", cur_item)

          item = Ops.get(cur_item, 0)

          next if !HostSystemPopup(Ops.get_string(item, 1, ""), true)

          table_items = Builtins.filter(table_items) do |e|
            ip = Ops.get_string(e, 1, "")
            if cur == Ops.get(e, [0, 0])
              if ip != "" && !ip.nil?
                deleted_items = Builtins.add(deleted_items, ip)
                next false
              end
            end
            true
          end
          UI.ChangeWidget(Id(:table), :Items, table_items)
          Host.SetModified
          next
        elsif ret == :back
          break
        elsif ret == :next
          # check_
          if Host.GetModified
            Host.clear
            Builtins.foreach(table_items) do |row|
              value = Builtins.mergestring(
                Builtins.prepend(
                  Punycode.EncodePunycodes([Ops.get_string(row, 3, "")]),
                  Punycode.EncodeDomainName(Ops.get_string(row, 2, ""))
                ),
                " "
              )
              key = Ops.get_string(row, 1, "")
              Host.add_name(key, value)
            end
          end
          break
        else
          Builtins.y2error("unexpected retcode: %1", ret)
          next
        end
      end

      Builtins.y2debug("table_items=%1", table_items)
      Builtins.y2debug("hosts=%1", hosts)

      Convert.to_symbol(ret)
    end

    def HostDialog(id, entry)
      entry = deep_copy(entry)
      Builtins.y2debug("id=%1", id)
      Builtins.y2debug("entry=%1", entry)
      # y2debug("forbidden=%1", forbidden);

      UI.OpenDialog(
        Opt(:decorated),
        VBox(
          MarginBox(
            1.5,
            0,
            VBox(
              HSpacing(20),
              # TextEntry label
              TextEntry(
                Id(:host),
                _("&IP Address"),
                Ops.get_string(entry, 1, "")
              ),
              VSpacing(0.5),
              # TextEntry label
              TextEntry(Id(:name), Label.HostName, Ops.get_string(entry, 2, "")),
              # TextEntry label
              VSpacing(0.5),
              TextEntry(
                Id(:aliases),
                _("Hos&t Aliases"),
                Ops.get_string(entry, 3, "")
              )
            )
          ),
          ButtonBox(
            PushButton(Id(:ok), Opt(:default, :okButton), Label.OKButton),
            PushButton(Id(:cancel), Opt(:cancelButton), Label.CancelButton)
          )
        )
      )

      UI.ChangeWidget(Id(:host), :ValidChars, IP.ValidChars)
      #    anything allowed here - will be converted to punycode (#448486)
      #    UI::ChangeWidget(`id(`name), `ValidChars, Hostname::ValidCharsFQ);
      #    UI::ChangeWidget(`id(`aliases), `ValidChars, Hostname::ValidCharsFQ + " ");

      if entry == term(:empty)
        UI.SetFocus(Id(:host))
      else
        UI.SetFocus(Id(:aliases))
      end

      ret = nil
      host = nil

      loop do
        host = nil
        ret = UI.UserInput
        break if ret != :ok

        host = Item(Id(id))
        val = Convert.to_string(UI.QueryWidget(Id(:host), :Value))
        if !IP.Check(val)
          # Popup::Error text
          Popup.Error(_("The IP address is invalid."))
          UI.SetFocus(Id(:host))
          next
        end

        host = Builtins.add(host, val)

        val = Convert.to_string(UI.QueryWidget(Id(:name), :Value))
        if !Hostname.CheckFQ(Punycode.EncodeDomainName(val))
          UI.SetFocus(Id(:name))
          # Popup::Error text
          Popup.Error(
            Ops.add(_("The hostname is invalid.") + "\n", Hostname.ValidFQ)
          )
          next
        end
        host = Builtins.add(host, val)

        val = Convert.to_string(UI.QueryWidget(Id(:aliases), :Value))
        if val != ""
          vals = Punycode.EncodePunycodes(Builtins.splitstring(val, " "))
          vals = Builtins.filter(vals) { |ho| ho != "" && !Hostname.CheckFQ(ho) }
          if Ops.greater_than(Builtins.size(vals), 0)
            UI.SetFocus(Id(:aliases))
            # Popup::Error text
            Popup.Error(
              Builtins.sformat(
                Ops.add(
                  _("Alias name \"%1\" is invalid.") + "\n",
                  Hostname.ValidFQ
                ),
                Ops.get(vals, 0, "")
              )
            )
            next
          end
        end
        host = Builtins.add(host, val)
        break
      end

      UI.CloseDialog
      return nil if ret != :ok

      Host.SetModified
      deep_copy(host)
    end
  end
end
