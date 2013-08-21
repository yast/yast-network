# encoding: utf-8

#***************************************************************************
#
# Copyright (c) 2008 - 2012 Novell, Inc.
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

# File:	firewall_stage1_proposal.ycp
# Summary:	Configuration of fw in 1st stage
# Author:	Bubli <kmachalkova@suse.cz>
#
module Yast
  class FirewallStage1ProposalClient < Client
    def main
      Yast.import "UI"
      textdomain "network"

      Yast.import "Label"
      Yast.import "Linuxrc"
      Yast.import "PackagesProposal"
      Yast.import "ProductControl"
      Yast.import "ProductFeatures"
      Yast.import "SuSEFirewall4Network"
      Yast.import "SuSEFirewallProposal"
      Yast.import "Wizard"

      @PROPOSAL_ID = "fw_1ststage"

      @LINK_ENABLE_FIREWALL = "firewall--enable_firewall_in_proposal"
      @LINK_DISABLE_FIREWALL = "firewall--disable_firewall_in_proposal"
      @LINK_ENABLE_SSH = "firewall--enable_ssh_in_proposal"
      @LINK_DISABLE_SSH = "firewall--disable_ssh_in_proposal"
      @LINK_ENABLE_VNC = "firewall--enable_vnc_in_proposal"
      @LINK_DISABLE_VNC = "firewall--disable_vnc_in_proposal"
      @LINK_FIREWALL_DIALOG = "firewall_stage1"

      # run this only once
      if !SuSEFirewallProposal.GetProposalInitialized
        # variables from control file
        Builtins.y2milestone(
          "Default firewall values: enable_firewall=%1, enable_ssh=%2",
          ProductFeatures.GetBooleanFeature("globals", "enable_firewall"),
          ProductFeatures.GetBooleanFeature("globals", "firewall_enable_ssh")
        )

        SuSEFirewall4Network.SetEnabled1stStage(
          ProductFeatures.GetBooleanFeature("globals", "enable_firewall")
        )

        #we're installing over SSH, propose opening SSH port (bnc#535206)
        if Linuxrc.usessh
          SuSEFirewall4Network.SetSshEnabled1stStage(true)
        else
          SuSEFirewall4Network.SetSshEnabled1stStage(
            ProductFeatures.GetBooleanFeature("globals", "firewall_enable_ssh")
          )
        end

        #we're installing over VNC, propose opening VNC port (bnc#734264)
        SuSEFirewall4Network.SetVncEnabled1stStage(true) if Linuxrc.vnc

        SuSEFirewallProposal.SetProposalInitialized(true)
      end


      @func = Convert.to_string(WFM.Args(0))
      @param = Convert.to_map(WFM.Args(1))
      @ret = {}


      if @func == "MakeProposal"
        # Summary is visible only if installing over VNC
        # and if firewall is enabled - otherwise port could not be blocked
        @vnc_proposal = Linuxrc.vnc && SuSEFirewall4Network.Enabled1stStage ?
          Ops.add(
            Ops.add(
              "<li>",
              SuSEFirewall4Network.EnabledVnc1stStage ?
                Builtins.sformat(
                  _("VNC ports will be open (<a href=\"%1\">close</a>)"),
                  @LINK_DISABLE_VNC
                ) :
                Builtins.sformat(
                  _("VNC ports will be blocked (<a href=\"%1\">open</a>)"),
                  @LINK_ENABLE_VNC
                )
            ),
            "</li>\n"
          ) :
          ""

        @output = Ops.add(
          Ops.add(
            Ops.add(
              Ops.add(
                Ops.add(
                  Ops.add(
                    Ops.add(
                      "<ul>\n" + "<li>",
                      SuSEFirewall4Network.Enabled1stStage ?
                        Builtins.sformat(
                          _(
                            "Firewall will be enabled (<a href=\"%1\">disable</a>)"
                          ),
                          @LINK_DISABLE_FIREWALL
                        ) :
                        Builtins.sformat(
                          _(
                            "Firewall will be disabled (<a href=\"%1\">enable</a>)"
                          ),
                          @LINK_ENABLE_FIREWALL
                        )
                    ),
                    "</li>\n"
                  ),
                  # Summary is visible even if firewall is disabled - it also installs and enables the SSHD service
                  "<li>"
                ),
                SuSEFirewall4Network.EnabledSsh1stStage ?
                  Builtins.sformat(
                    _(
                      "SSH service will be enabled, SSH port will be open (<a href=\"%1\">disable and close</a>)"
                    ),
                    @LINK_DISABLE_SSH
                  ) :
                  Builtins.sformat(
                    _(
                      "SSH service will be disabled, SSH port will be blocked (<a href=\"%1\">enable and open</a>)"
                    ),
                    @LINK_ENABLE_SSH
                  )
              ),
              "</li>\n"
            ),
            @vnc_proposal
          ),
          "</ul>\n"
        )

        @ret = {
          "preformatted_proposal" => @output,
          "warning_level"         => :warning,
          "links"                 => [
            @LINK_ENABLE_FIREWALL,
            @LINK_DISABLE_FIREWALL,
            @LINK_ENABLE_SSH,
            @LINK_DISABLE_SSH,
            @LINK_ENABLE_VNC,
            @LINK_DISABLE_VNC
          ]
        }
      elsif @func == "AskUser"
        @chosen_link = Ops.get(@param, "chosen_id")
        @result = :next
        Builtins.y2milestone("User clicked %1", @chosen_link)

        if @chosen_link == @LINK_ENABLE_FIREWALL
          Builtins.y2milestone("Enabling FW")
          SuSEFirewall4Network.SetEnabled1stStage(true)
          PackagesProposal.AddResolvables(
            @PROPOSAL_ID,
            :package,
            ["SuSEfirewall2"]
          )
        elsif @chosen_link == @LINK_DISABLE_FIREWALL
          Builtins.y2milestone("Disabling FW")
          SuSEFirewall4Network.SetEnabled1stStage(false)
          PackagesProposal.RemoveResolvables(
            @PROPOSAL_ID,
            :package,
            ["SuSEfirewall2"]
          )
        elsif @chosen_link == @LINK_ENABLE_SSH
          Builtins.y2milestone("Enabling SSH")
          PackagesProposal.AddResolvables(@PROPOSAL_ID, :package, ["openssh"])
          SuSEFirewall4Network.SetSshEnabled1stStage(true)
        elsif @chosen_link == @LINK_DISABLE_SSH
          Builtins.y2milestone("Disabling SSH")
          SuSEFirewall4Network.SetSshEnabled1stStage(false)
          PackagesProposal.RemoveResolvables(
            @PROPOSAL_ID,
            :package,
            ["openssh"]
          )
        elsif @chosen_link == @LINK_ENABLE_VNC
          Builtins.y2milestone("Enabling VNC")
          SuSEFirewall4Network.SetVncEnabled1stStage(true)
        elsif @chosen_link == @LINK_DISABLE_VNC
          Builtins.y2milestone("Disabling VNC")
          SuSEFirewall4Network.SetVncEnabled1stStage(false)
        elsif @chosen_link == @LINK_FIREWALL_DIALOG
          @result = FirewallDialogSimple()
        end

        SuSEFirewallProposal.SetChangedByUser(true)

        @ret = { "workflow_sequence" => @result }

      elsif @func == "Description"
        @ret = {
          # Proposal title
          "rich_text_title" => _("Firewall and SSH"),
          # Menu entry label
          "menu_title"      => _("&Firewall and SSH"),
          "id"              => @LINK_FIREWALL_DIALOG
        }
      elsif @func == "Write"
        @ret = { "success" => true }
      end

      deep_copy(@ret)
    end

    def FirewallDialogSimple
      title = _("Basic Firewall and SSH Configuration")

      vnc_support = Left(
        CheckBox(
          Id("open_vnc_port"),
          # TRANSLATORS: check-box label
          _("Open &VNC Ports"),
          SuSEFirewall4Network.EnabledVnc1stStage
        )
      )

      contents = VBox(
        Frame(
          # frame label
          _("Firewall and SSH service"),
          HSquash(
            MarginBox(
              0.5,
              0.5,
              VBox(
                Left(
                  CheckBox(
                    Id("enable_fw"),
                    Opt(:notify),
                    # TRANSLATORS: check-box label
                    _("Enable Firewall"),
                    SuSEFirewall4Network.Enabled1stStage
                  )
                ),
                Left(
                  CheckBox(
                    Id("open_ssh_port"),
                    # TRANSLATORS: check-box label
                    _("Open SSH Port and Enable SSH Service"),
                    SuSEFirewall4Network.EnabledSsh1stStage
                  )
                ),
                Linuxrc.vnc ? vnc_support : Empty()
              )
            )
          )
        )
      )

      help = _(
        "<p><b><big>Firewall and SSH</big></b><br>\n" +
          "Firewall is a defensive mechanism that protects your computer from network attacks.\n" +
          "SSH is a service that allows logging into this computer remotely via dedicated\n" +
          "SSH client</p>"
      ) +
        _(
          "<p>Here you can choose whether the firewall will be enabled or disabled after\nthe installation. It is recommended to keep it enabled.</p>"
        ) +
        _(
          "<p>With enabled firewall, you can decide whether to open firewall port for SSH\n" +
            "service and allow remote SSH logins. This will also enable SSH service (i.e. it\n" +
            "will be started on computer boot).</p>"
        ) +
        (Linuxrc.vnc ?
          # TRANSLATORS: help text
          _(
            "<p>You can also open VNC ports in firewall. It will not enable\n" +
              "the remote administration service on a running system but it is\n" +
              "started by the installer automatically if needed.</p>"
          ) :
          "")

      Wizard.CreateDialog
      Wizard.SetTitleIcon("yast-firewall")

      Wizard.SetContentsButtons(
        title,
        contents,
        help,
        Label.BackButton,
        Label.OKButton
      )
      Wizard.SetAbortButton(:cancel, Label.CancelButton)
      Wizard.HideBackButton

      UI.ChangeWidget(
        Id("open_ssh_port"),
        :Enabled,
        SuSEFirewall4Network.Enabled1stStage
      )
      UI.ChangeWidget(
        Id("open_vnc_port"),
        :Enabled,
        SuSEFirewall4Network.Enabled1stStage
      )

      dialog_ret = nil

      while true
        dialog_ret = UI.UserInput
        enable_firewall = Convert.to_boolean(
          UI.QueryWidget(Id("enable_fw"), :Value)
        )

        if dialog_ret == "enable_fw"
          UI.ChangeWidget(Id("open_ssh_port"), :Enabled, enable_firewall)
          UI.ChangeWidget(Id("open_vnc_port"), :Enabled, enable_firewall)
          next
        elsif dialog_ret == :next || dialog_ret == :ok
          open_ssh_port = Convert.to_boolean(
            UI.QueryWidget(Id("open_ssh_port"), :Value)
          )
          open_vnc_port = Convert.to_boolean(
            UI.QueryWidget(Id("open_vnc_port"), :Value)
          )

          SuSEFirewall4Network.SetEnabled1stStage(enable_firewall)

          if enable_firewall
            SuSEFirewall4Network.SetSshEnabled1stStage(open_ssh_port)
            SuSEFirewall4Network.SetVncEnabled1stStage(open_vnc_port)
          end
        end

        # anything but enabling the firewall closes this dialog
        # (VNC and SSH checkboxes do nothing)
        break
      end

      Wizard.CloseDialog
      Convert.to_symbol(dialog_ret)
    end
  end
end

Yast::FirewallStage1ProposalClient.new.main
