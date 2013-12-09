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
# File:	clients/lan_proposal.ycp
# Package:	Network configuration
# Summary:	Lan configuration proposal
# Authors:	Michal Svec <msvec@suse.cz>
#
module Yast
  class LanProposalClient < Client
    def main
      Yast.import "UI"

      textdomain "network"

      # The main ()
      Builtins.y2milestone("----------------------------------------")
      Builtins.y2milestone("Lan proposal started")
      Builtins.y2milestone("Arguments: %1", WFM.Args)

      Yast.import "Arch"
      Yast.import "Lan"
      Yast.import "Linuxrc"
      Yast.import "Popup"
      Yast.import "Progress"
      Yast.import "LanItems"

      Yast.include self, "network/lan/wizards.rb"

      @args = WFM.Args

      # yast2-installation calls the method this way:
      #
      #  WFM::CallFunction( <proposal>, [<client function>, <map of arguments>])
      #
      # see inst_proposal.ycp
      @func = Ops.get_string(@args, 0, "")
      @param = Ops.get_map(@args, 1, {})

      @ret = {}

      # create a textual proposal
      if @func == "MakeProposal"
        @proposal = ""
        @warning = nil
        @warning_level = nil
        @force_reset = Ops.get_boolean(@param, "force_reset", false)

        Builtins.y2milestone(
          "lan_proposal/MakeProposal force_reset: %1",
          @force_reset
        )

        if @force_reset || !LanItems.proposal_valid
          LanItems.proposal_valid = true

          BusyPopup(_("Detecting network cards..."))

          @progress_orig = Progress.set(false)

          # NM wants us to repropose but while at it Lan::Read should not
          # think it does a full reread and unset Lan::modified. #147270
          Lan.Read(@force_reset ? :nocache : :cache)

          if Lan.virt_net_proposal == nil
            Lan.virt_net_proposal = VirtProposalRequired()
          end

          Lan.Propose
          Progress.set(@progress_orig)

          BusyPopupClose()
        end

        @sum = Lan.Summary("proposal")
        @proposal = Ops.get_string(@sum, 0, "")

        @ret = {
          "preformatted_proposal" => @proposal,
          "warning_level"         => @warning_level, # TODO `warning
          "warning"               => @warning, # TODO WiFi but no encryption
          "links"                 => Ops.get_list(@sum, 1, [])
        }
      # run the module
      elsif @func == "AskUser"
        @stored = Lan.Export

        @chosen_id = Ops.get_string(@param, "chosen_id", "")
        @seq = :next
        @match = Builtins.regexptokenize(
          @chosen_id,
          "^lan--wifi-encryption-(.*)"
        )
        if @match != nil && @match != []
          Builtins.y2milestone("%1", @chosen_id)
          @dev = Ops.get(@match, 0, "")
          # unescape colons
          @dev = Builtins.mergestring(Builtins.splitstring(@dev, "/"), ":")
          #	Lan::Edit (dev);

          Builtins.foreach(LanItems.Items) do |row, value|
            LanItems.current = row
            if LanItems.IsCurrentConfigured
              if Builtins.issubstring(
                  @dev,
                  Ops.get_string(LanItems.getCurrentItem, "ifcfg", "")
                )
                LanItems.SetItem
                raise Break
              end
            end
          end if IsNotEmpty(
            @dev
          )


          # #113196: must create new dialog for proposal clients
          Wizard.CreateDialog
          Wizard.SetDesktopTitleAndIcon("lan")
          @seq = AddressSequence("wire")

          Wizard.CloseDialog
        else
          @seq = LanAutoSequence("proposal")
        end

        if @seq != :next
          LanItems.Items = {}
          Lan.Import(@stored)
        end
        @ret = { "workflow_sequence" => @seq }
      # create titles
      elsif @func == "Description"
        @ret = {
          # RichText label
          "rich_text_title" => _("Network Interfaces"),
          # Menu label
          "menu_title"      => _("&Network Interfaces"),
          "id"              => "lan"
        }
      # write the proposal
      elsif @func == "Write"
        if PackagesInstall(Lan.Packages) != :next
          # popup already shown
          Builtins.y2error("Packages installation failure, not saving")
        elsif !Lan.virt_net_proposal &&
            (Linuxrc.display_ip || Linuxrc.vnc || Linuxrc.usessh)
          Builtins.y2milestone("write only")
          Lan.WriteOnly
        else
          Lan.Write
          # With a little help from my friends:
          # Let yast2-printer listen for CUPS broadcasts
          SCR.Execute(
            path(".target.bash_background"),
            "test -f /usr/lib/YaST2/bin/listen_remote_ipp && /usr/lib/YaST2/bin/listen_remote_ipp 120"
          )
        end
      else
        Builtins.y2error("unknown function: %1", @func)
      end

      # Finish
      Builtins.y2debug("ret=%1", @ret)
      Builtins.y2milestone("Lan proposal finished")
      Builtins.y2milestone("----------------------------------------")
      deep_copy(@ret) 

      # EOF
    end

    # Decides if a proposal for virtualization host machine is required.
    def VirtProposalRequired
      # S390 has special requirements. See bnc#817943
      return false if Arch.s390

      return true if PackageSystem.Installed("xen") && !Arch.is_xenU
      return true if PackageSystem.Installed("kvm")
      return true if PackageSystem.Installed("qemu")

      false
    end
  end
end

Yast::LanProposalClient.new.main
