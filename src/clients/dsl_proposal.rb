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
# File:	clients/dsl_proposal.ycp
# Package:	Network configuration
# Summary:	DSL configuration proposal
# Authors:	Michal Svec <msvec@suse.cz>
#
module Yast
  class DslProposalClient < Client
    def main
      Yast.import "UI"

      textdomain "network"

      # The main ()
      Builtins.y2milestone("----------------------------------------")
      Builtins.y2milestone("DSL proposal started")
      Builtins.y2milestone("Arguments: %1", WFM.Args)

      Yast.import "DSL"
      Yast.import "Popup"
      Yast.import "Progress"
      Yast.import "GetInstArgs"

      Yast.include self, "network/routines.rb"

      @func = Convert.to_string(WFM.Args(0))
      @param = Convert.to_map(WFM.Args(1))
      @ret = {}

      # create a textual proposal
      if @func == "MakeProposal"
        @proposal = ""
        @warning = nil
        @warning_level = nil
        @force_reset = Ops.get_boolean(@param, "force_reset", false)

        if @force_reset || !DSL.proposal_valid
          DSL.proposal_valid = true
          if !GetInstArgs.automatic_configuration
            # Popup text
            BusyPopup(_("Detecting DSL devices..."))
          end
          @progress_orig = Progress.set(false)
          DSL.Read
          DSL.Propose
          Progress.set(@progress_orig)
          BusyPopupClose() if !GetInstArgs.automatic_configuration
        end
        @sum = DSL.Summary(false)
        @proposal = Ops.get_string(@sum, 0, "")

        @ret = {
          "preformatted_proposal" => @proposal,
          "warning_level"         => @warning_level,
          "warning"               => @warning
        }
      # run the module
      elsif @func == "AskUser"
        @stored = DSL.Export
        @result = Convert.to_symbol(WFM.CallFunction("dsl", [path(".propose")]))
        DSL.Import(@stored) if @result != :next
        Builtins.y2debug("stored=%1", @stored)
        Builtins.y2debug("result=%1", @result)
        @ret = { "workflow_sequence" => @result }
      # create titles
      elsif @func == "Description"
        @ret = {
          # RichText label
          "rich_text_title" => _("DSL Connections"),
          # Menu label
          "menu_title"      => _("&DSL Connections"),
          "id"              => "dsl"
        }
      # write the proposal
      elsif @func == "Write"
        if PackagesInstall(DSL.Packages) != :next
          # Popup text
          Popup.Error(
            "Required packages installation failed.\nDSL configuration cannot be saved."
          )
          Builtins.y2error("Packages installation failure, not saving")
        else
          DSL.Write
        end
      else
        Builtins.y2error("unknown function: %1", @func)
      end

      # Finish
      Builtins.y2debug("ret=%1", @ret)
      Builtins.y2milestone("DSL proposal finished")
      Builtins.y2milestone("----------------------------------------")
      deep_copy(@ret) 

      # EOF
    end
  end
end

Yast::DslProposalClient.new.main
