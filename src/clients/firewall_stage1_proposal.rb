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
    PROPOSAL_ID = "fw_1ststage"

    LINK_ENABLE_FIREWALL = "firewall--enable_firewall_in_proposal"
    LINK_DISABLE_FIREWALL = "firewall--disable_firewall_in_proposal"
    LINK_OPEN_SSH_PORT = "firewall--enable_ssh_port_in_proposal"
    LINK_BLOCK_SSH_PORT = "firewall--disable_ssh_port_in_proposal"
    LINK_ENABLE_SSHD = "firewall--enable_sshd_in_proposal"
    LINK_DISABLE_SSHD = "firewall--disable_sshd_in_proposal"
    LINK_ENABLE_VNC = "firewall--enable_vnc_in_proposal"
    LINK_DISABLE_VNC = "firewall--disable_vnc_in_proposal"
    LINK_FIREWALL_DIALOG = "firewall_stage1"


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

      # run this only once
      if !SuSEFirewallProposal.GetProposalInitialized
        # variables from control file
        Builtins.y2milestone(
          "Default firewall values: enable_firewall=%1, enable_ssh=%2 enable_sshd=%3",
          ProductFeatures.GetBooleanFeature("globals", "enable_firewall"),
          ProductFeatures.GetBooleanFeature("globals", "firewall_enable_ssh"),
          ProductFeatures.GetBooleanFeature("globals", "enable_sshd")
        )

        SuSEFirewall4Network.SetEnabled1stStage(
          ProductFeatures.GetBooleanFeature("globals", "enable_firewall")
        )

        # we're installing over SSH, propose opening SSH port (bnc#535206)
        if Linuxrc.usessh
          SuSEFirewall4Network.SetSshEnabled1stStage(true)
          SuSEFirewall4Network.SetSshdEnabled(true)
        else
          SuSEFirewall4Network.SetSshEnabled1stStage(
            ProductFeatures.GetBooleanFeature("globals", "firewall_enable_ssh")
          )
          SuSEFirewall4Network.SetSshdEnabled(
            ProductFeatures.GetBooleanFeature("globals", "enable_sshd")
          )
        end

        # we're installing over VNC, propose opening VNC port (bnc#734264)
        SuSEFirewall4Network.SetVncEnabled1stStage(true) if Linuxrc.vnc

        SuSEFirewallProposal.SetProposalInitialized(true)
      end


      @func = Convert.to_string(WFM.Args(0))
      @param = Convert.to_map(WFM.Args(1))
      @ret = {}


      if @func == "MakeProposal"
        # Summary is visible only if installing over VNC
        # and if firewall is enabled - otherwise port could not be blocked
        vnc_proposal_element = ""
        if Linuxrc.vnc && SuSEFirewall4Network.Enabled1stStage
          vnc_proposal = SuSEFirewall4Network.EnabledVnc1stStage ?
            _("VNC ports will be open (<a href=\"%s\">close</a>)") %
              LINK_DISABLE_VNC
            : _("VNC ports will be blocked (<a href=\"%s\">open</a>)") %
              LINK_ENABLE_VNC
          vnc_proposal_element = "<li>#{vnc_proposal}</li>"
        end

        firewall_proposal = SuSEFirewall4Network.Enabled1stStage ?
            _(
              "Firewall will be enabled (<a href=\"%s\">disable</a>)"
            ) % LINK_DISABLE_FIREWALL
          :
            _(
              "Firewall will be disabled (<a href=\"%s\">enable</a>)"
            ) % LINK_ENABLE_FIREWALL

        ssh_proposal = SuSEFirewall4Network.EnabledSsh1stStage ?
            _(
              "SSH port will be open (<a href=\"%s\">block</a>)"
            ) % LINK_BLOCK_SSH_PORT
          :
            _(
              "SSH port will be blocked (<a href=\"%s\">open</a>)"
            ) % LINK_OPEN_SSH_PORT

        sshd_proposal = SuSEFirewall4Network.EnabledSshd ?
            _(
              "SSH service will be enabled (<a href=\"%s\">disable</a>)"
            ) % LINK_DISABLE_SSHD
          :
            _(
              "SSH service will be disabled (<a href=\"%s\">enable</a>)"
            ) % LINK_ENABLE_SSHD




        @output = "<ul>\n<li>#{firewall_proposal}</li>\n" +
                  "<li>#{ssh_proposal}</li>\n" +
                  "<li>#{sshd_proposal}</li>\n" +
                  vnc_proposal_element +
                  "</ul>\n"

        @ret = {
          "preformatted_proposal" => @output,
          "warning_level"         => :warning,
          "links"                 => [
            LINK_ENABLE_FIREWALL,
            LINK_DISABLE_FIREWALL,
            LINK_OPEN_SSH_PORT,
            LINK_BLOCK_SSH_PORT,
            LINK_ENABLE_SSHD,
            LINK_DISABLE_SSHD,
            LINK_ENABLE_VNC,
            LINK_DISABLE_VNC
          ]
        }
      elsif @func == "AskUser"
        @chosen_link = Ops.get(@param, "chosen_id")
        @result = :next
        Builtins.y2milestone("User clicked %1", @chosen_link)

        case @chosen_link
        when LINK_ENABLE_FIREWALL
          Builtins.y2milestone("Enabling FW")
          SuSEFirewall4Network.SetEnabled1stStage(true)
          PackagesProposal.AddResolvables(
            PROPOSAL_ID,
            :package,
            ["SuSEfirewall2"]
          )
        when LINK_DISABLE_FIREWALL
          Builtins.y2milestone("Disabling FW")
          SuSEFirewall4Network.SetEnabled1stStage(false)
          PackagesProposal.RemoveResolvables(
            PROPOSAL_ID,
            :package,
            ["SuSEfirewall2"]
          )
        when LINK_OPEN_SSH_PORT
          Builtins.y2milestone("Opening SSH port")
          SuSEFirewall4Network.SetSshEnabled1stStage(true)
        when LINK_BLOCK_SSH_PORT
          Builtins.y2milestone("Blocking SSH port")
          SuSEFirewall4Network.SetSshEnabled1stStage(false)
        when LINK_ENABLE_SSHD
          Builtins.y2milestone("Enabling SSHD")
          PackagesProposal.AddResolvables(PROPOSAL_ID, :package, ["openssh"])
          SuSEFirewall4Network.SetSshdEnabled(true)
        when LINK_DISABLE_SSHD
          Builtins.y2milestone("Disabling SSHD")
          SuSEFirewall4Network.SetSshdEnabled(false)
          PackagesProposal.RemoveResolvables(
            PROPOSAL_ID,
            :package,
            ["openssh"]
          )
        when LINK_ENABLE_VNC
          Builtins.y2milestone("Enabling VNC")
          SuSEFirewall4Network.SetVncEnabled1stStage(true)
        when LINK_DISABLE_VNC
          Builtins.y2milestone("Disabling VNC")
          SuSEFirewall4Network.SetVncEnabled1stStage(false)
        when LINK_FIREWALL_DIALOG
          @result = FirewallDialogSimple()
        else
          raise "INTERNAL ERROR: unknown action '#{@chosen_link}' for proposal client"
        end

        SuSEFirewallProposal.SetChangedByUser(true)

        @ret = { "workflow_sequence" => @result }

      elsif @func == "Description"
        @ret = {
          # Proposal title
          "rich_text_title" => _("Firewall and SSH"),
          # Menu entry label
          "menu_title"      => _("&Firewall and SSH"),
          "id"              => LINK_FIREWALL_DIALOG
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
                    _("Open SSH Port"),
                    SuSEFirewall4Network.EnabledSsh1stStage
                  )
                ),
                Left(
                  CheckBox(
                    Id("enable_sshd"),
                    # TRANSLATORS: check-box label
                    _("Enable SSH Service"),
                    SuSEFirewall4Network.EnabledSshd
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
            "service and allow remote SSH logins. Independently you can also enable SSH service (i.e. it\n" +
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

          SuSEFirewall4Network.SetSshdEnabled(
            UI::QueryWidget(Id("enable_sshd"), :Value)
          )
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
