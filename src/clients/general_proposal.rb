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
# File:	clients/general_proposal.ycp
# Package:	Network configuration
# Summary:	Network mode + ipv6 proposal
# Authors:	Martin Vidner <mvidner@suse.cz>
#
#
# This is not a standalone proposal, it depends on lan_proposal. It
# must run after it.
module Yast
  class GeneralProposalClient < Client
    def main
      Yast.import "UI"

      textdomain "network"

      # The main ()
      Builtins.y2milestone("----------------------------------------")
      Builtins.y2milestone("General network settings proposal started")
      Builtins.y2milestone("Arguments: %1", WFM.Args)

      Yast.import "Lan"
      Yast.import "LanItems"
      Yast.import "NetworkService"

      Yast.include self, "network/lan/complex.rb"

      @args = WFM.Args

      @func = Ops.get_string(@args, 0, "")
      @param = Ops.get_map(@args, 1, {})
      @ret = {}

      # create a textual proposal
      if @func == "MakeProposal"
        @proposal = ""
        @links = []
        @warning = nil
        @warning_level = nil

        @sum = Lan.SummaryGeneral
        @proposal = Ops.get_string(@sum, 0, "")
        @links = Ops.get_list(@sum, 1, [])

        @ret = {
          "preformatted_proposal" => @proposal,
          "links"                 => @links,
          "warning_level"         => @warning_level,
          "warning"               => @warning
        }
      # run the module
      elsif @func == "AskUser"
        @chosen_id = Ops.get_string(@param, "chosen_id", "")
        @seq = :next
        if @chosen_id == "lan--nm-enable"
          NetworkService.SetManaged(true)
        elsif @chosen_id == "lan--nm-disable"
          NetworkService.SetManaged(false)
        elsif @chosen_id == "ipv6-enable"
          Lan.SetIPv6(true)
        elsif @chosen_id == "ipv6-disable"
          Lan.SetIPv6(false)
        elsif @chosen_id == "virtual-enable"
          Lan.virt_net_proposal = true
        elsif @chosen_id == "virtual-revert"
          Lan.virt_net_proposal = false
        else
          Wizard.CreateDialog
          Wizard.SetDesktopTitleAndIcon("lan")

          @seq = ManagedDialog()
          Wizard.CloseDialog
        end
        LanItems.proposal_valid = false # repropose
        LanItems.SetModified
        @ret = { "workflow_sequence" => @seq }
      # create titles
      elsif @func == "Description"
        @ret = {
          # RichText label
          "rich_text_title" => _("General Network Settings"),
          # Menu label
          "menu_title"      => _("General &Network Settings"),
          "id"              => "networkmode"
        }
      # write the proposal
      elsif @func == "Write"
        Builtins.y2debug("lan_proposal did it")
      else
        Builtins.y2error("unknown function: %1", @func)
      end

      # Finish
      Builtins.y2debug("ret=%1", @ret)
      Builtins.y2milestone("General network settings proposal finished")
      Builtins.y2milestone("----------------------------------------")
      deep_copy(@ret) 

      # EOF
    end
  end
end

Yast::GeneralProposalClient.new.main
