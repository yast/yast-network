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
# File:	clients/isdn_proposal.ycp
# Package:	Configuration of network
# Summary:	ISDN configuration proposal
# Authors:	Michal Svec <msvec@suse.cz>
#
module Yast
  class IsdnProposalClient < Client
    def main
      Yast.import "UI"

      textdomain "network"

      # The main ()
      Builtins.y2milestone("----------------------------------------")
      Builtins.y2milestone("ISDN proposal started")
      Builtins.y2milestone("Arguments: %1", WFM.Args)

      Yast.import "ISDN"
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

        if @force_reset || !ISDN.proposal_valid
          ISDN.proposal_valid = true
          if !GetInstArgs.automatic_configuration
            # Popup text
            BusyPopup(_("Detecting ISDN cards..."))
          end
          @progress_orig = Progress.set(false)
          ISDN.Read
          # no ISDN::Propose () ?
          Progress.set(@progress_orig)
          BusyPopupClose() if !GetInstArgs.automatic_configuration
        end
        @sum = ISDN.Summary(false)
        @proposal = Ops.get_string(@sum, 0, "")

        @ret = {
          "preformatted_proposal" => @proposal,
          "warning_level"         => @warning_level,
          "warning"               => @warning
        }
      # run the module
      elsif @func == "AskUser"
        @stored = ISDN.Export
        @seq = WFM.CallFunction("isdn", [path(".propose")])
        ISDN.Import(@stored) if @seq != :next
        @ret = { "workflow_sequence" => @seq }
      # create titles
      elsif @func == "Description"
        @ret = {
          # RichText label
          "rich_text_title" => _("ISDN Adapters"),
          # Menu label
          "menu_title"      => _("&ISDN Adapters"),
          "id"              => "isdn"
        }
      # write the proposal
      elsif @func == "Write"
        ISDN.Write(true) # #74096, full init before internet test
      else
        Builtins.y2error("unknown function: %1", @func)
      end

      # Finish
      Builtins.y2debug("ret=%1", @ret)
      Builtins.y2milestone("ISDN proposal finished")
      Builtins.y2milestone("----------------------------------------")
      deep_copy(@ret) 

      # EOF
    end
  end
end

Yast::IsdnProposalClient.new.main
