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
# File:	clients/provider.ycp
# Package:	Network configuration
# Summary:	Provider main file
# Authors:	Michal Svec <msvec@suse.cz>
#
#
# Main file for provider configuration.
# Uses all other files.
module Yast
  module NetworkProviderComplexInclude
    def initialize_network_provider_complex(include_target)
      textdomain "network"

      Yast.import "Label"
      Yast.import "Popup"
      Yast.import "Provider"
      Yast.import "Wizard"

      Yast.include include_target, "network/routines.rb"
      Yast.include include_target, "network/summary.rb"
      Yast.include include_target, "network/provider/helps.rb"
    end

    # Commit changes to internal structures
    # @return always `next
    def CommitProvider
      Provider.Commit
      :next
    end

    # Read settings dialog
    # @return `abort if aborted and `next otherwise
    def ReadDialog
      Wizard.RestoreHelp(Ops.get_string(@HELPS, "read", ""))
      # Provider::AbortFunction = ``{return PollAbort();};
      ret = Provider.Read
      ret ? :next : :abort
    end

    # Write settings dialog
    # @return `abort if aborted and `next otherwise
    def WriteDialog
      return :next if !Modified()
      Wizard.RestoreHelp(Ops.get_string(@HELPS, "write", ""))
      # Provider::AbortFunction = ``{return PollAbort() && ReallyAbort();};
      ret = Provider.Write("all")
      ret ? :next : :abort
    end

    # Choose provider type dialog
    # @return `abort if aborted and `next otherwise
    def TypeDialog
      # Provider type dialog caption
      caption = _("Provider Type")

      # Provider type dialog contents
      contents = HBox(
        HSpacing(8),
        # Frame label
        #`Frame(_("Available network modules:"), `HBox(`HSpacing(2),
        VBox(
          VSpacing(3),
          # Selection box label
          SelectionBox(
            Id(:modules),
            _("&Available Provider Types:"),
            [
              # Selection box item
              Item(Id("modem"), _("Modem Provider"), true),
              # Selection box item
              Item(Id("isdn"), _("ISDN Provider")),
              # Selection box item
              Item(Id("dsl"), _("DSL Provider"))
            ]
          ),
          VSpacing(3)
        ),
        #`HSpacing(2))),
        HSpacing(8)
      )

      Wizard.SetContentsButtons(
        caption,
        contents,
        Ops.get_string(@HELPS, "type", ""),
        Label.BackButton,
        Label.NextButton
      )

      UI.SetFocus(Id(:modules))

      ret = nil
      while true
        ret = UI.UserInput

        # abort?
        if ret == :abort || ret == :cancel
          # if(ReallyAbort()) break;
          # else continue;
          break
        # next
        elsif ret == :next
          # check_*
          break
        # back
        elsif ret == :back
          break
        else
          Builtins.y2error("unexpected retcode: %1", ret)
          next
        end
      end

      if ret == :next
        type = Convert.to_string(UI.QueryWidget(Id(:modules), :CurrentItem))
        Builtins.y2debug("type=%1", type)
        Provider.Add(type)
      end

      deep_copy(ret)
    end

    # Overview dialog
    # @return dialog result
    def OverviewDialog
      # Provider overview dialog help caption
      caption = _("Provider Overview")

      overview = Provider.Overview("all")
      Builtins.y2debug("overview=%1", overview)

      contents = OverviewTable(
        # Table header
        Header(_("Name"), _("Provider"), _("Phone")),
        # `header(_("Name"), _("Provider"), _("Phone"), _("Modem"), _("ISDN"), _("DSL")),
        overview
      )

      Wizard.SetContentsButtons(
        caption,
        contents,
        Ops.get_string(@HELPS, "overview", ""),
        Label.BackButton,
        Label.FinishButton
      )

      if Ops.less_than(Builtins.size(overview), 1)
        UI.ChangeWidget(Id(:edit), :Enabled, false)
        UI.ChangeWidget(Id(:delete), :Enabled, false)
      else
        UI.SetFocus(Id(:table))
      end

      ret = nil
      while true
        ret = UI.UserInput

        # abort?
        if ret == :abort || ret == :cancel
          if ReallyAbort()
            break
          else
            next
          end
        # add
        elsif ret == :add
          break
        # edit
        elsif ret == :edit || ret == :table
          dev = Convert.to_string(UI.QueryWidget(Id(:table), :CurrentItem))
          Provider.Edit(dev)
          break
        # delete
        elsif ret == :delete
          dev = Convert.to_string(UI.QueryWidget(Id(:table), :CurrentItem))
          Provider.Delete(dev)
          Provider.Commit
          overview = Provider.Overview("all")
          UI.ChangeWidget(Id(:table), :Items, overview)
          if Ops.less_than(Builtins.size(overview), 1)
            UI.ChangeWidget(Id(:edit), :Enabled, false)
            UI.ChangeWidget(Id(:delete), :Enabled, false)
          end
          Builtins.y2debug("overview=%1", overview)
          next
        elsif ret == :next || ret == :back
          break
        else
          Builtins.y2error("unexpected retcode: %1", ret)
          next
        end
      end

      deep_copy(ret)
    end
  end
end
