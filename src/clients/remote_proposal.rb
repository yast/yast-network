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
# File:        clients/remote_proposal.ycp
# Package:     Network configuration
# Summary:     Proposal for Remote Administration
# Authors:     Arvin Schnell <arvin@suse.de>
#		Michal Svec <msvec@suse.cz>
#
module Yast
  class RemoteProposalClient < Client
    def main
      Yast.import "UI"

      textdomain "network"

      # The main ()
      Builtins.y2milestone("----------------------------------------")
      Builtins.y2milestone("Remote proposal started")
      Builtins.y2milestone("Arguments: %1", WFM.Args)

      Yast.import "Remote"
      Yast.import "Wizard"
      Yast.include self, "network/remote/dialogs.rb"

      @func = Convert.to_string(WFM.Args(0))
      @param = Convert.to_map(WFM.Args(1))
      @ret = {}

      # create a textual proposal
      if @func == "MakeProposal"
        @proposal = ""
        @warning = nil
        @warning_level = nil
        @force_reset = Ops.get_boolean(@param, "force_reset", false)

        if @force_reset
          Remote.Reset
        else
          Remote.Propose
        end
        @ret = { "raw_proposal" => [Remote.Summary] }
      # run the module
      elsif @func == "AskUser"
        # single dialog, no need to Export/Import

        Wizard.CreateDialog
        Wizard.SetDesktopIcon("remote")
        @result = RemoteMainDialog()
        UI.CloseDialog

        Builtins.y2debug("result=%1", @result)
        @ret = { "workflow_sequence" => @result }
      # create titles
      elsif @func == "Description"
        @ret = {
          # RichText label
          "rich_text_title" => _("VNC Remote Administration"),
          # Menu label
          "menu_title"      => _("VNC &Remote Administration"),
          "id"              => "admin_stuff"
        }
      # write the proposal
      elsif @func == "Write"
        Remote.Write
      else
        Builtins.y2error("unknown function: %1", @func)
      end

      # Finish
      Builtins.y2debug("ret=%1", @ret)
      Builtins.y2milestone("Remote proposal finished")
      Builtins.y2milestone("----------------------------------------")
      deep_copy(@ret)

      # EOF
    end
  end
end

Yast::RemoteProposalClient.new.main
