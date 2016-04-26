# encoding: utf-8

# ***************************************************************************
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
# **************************************************************************

# File:	firewall_stage1_proposal.ycp
# Author:	Bubli <kmachalkova@suse.cz>
#
require "yast"

# yast namespace
module Yast
  # Configuration of fw in 1st stage
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

    # Namespace for UI constants
    module ID
      SSH_PORT = "open_ssh_port"
      VNC_PORT = "open_vnc_port"
      ENABLE_FW = "enable_fw"
      ENABLE_SSHD = "enable_sshd"
    end

    include Yast::Logger

    def main
      Yast.import "UI"
      textdomain "network"

      Yast.import "Label"
      Yast.import "Linuxrc"
      Yast.import "PackagesProposal"
      Yast.import "ProductControl"
      Yast.import "Progress"
      Yast.import "SuSEFirewall"
      Yast.import "SuSEFirewall4Network"
      Yast.import "SuSEFirewallProposal"
      Yast.import "Wizard"

      script_command = WFM.Args(0)
      params = WFM.Args(1) || {}
      script_return = {}

      case script_command
      when "MakeProposal"
        # Don't override users settings
        SuSEFirewall4Network.prepare_proposal unless SuSEFirewallProposal.GetChangedByUser

        # this method is not easily mockable in rspec and currently is out of scope
        # for testing in firewall_stage1_proposal_test.rb
        adjust_configuration if !Mode.test

        script_return = {
          "preformatted_proposal" => preformatted_proposal,
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
      when "AskUser"
        chosen_link = params["chosen_id"]
        result = :next
        log.info "User clicked #{chosen_link}"

        case chosen_link
        when LINK_ENABLE_FIREWALL
          log.info "Enabling FW"
          SuSEFirewall4Network.SetEnabled1stStage(true)
        when LINK_DISABLE_FIREWALL
          log.info "Disabling FW"
          SuSEFirewall4Network.SetEnabled1stStage(false)
        when LINK_OPEN_SSH_PORT
          log.info "Opening SSH port"
          SuSEFirewall4Network.SetSshEnabled1stStage(true)
        when LINK_BLOCK_SSH_PORT
          log.info "Blocking SSH port"
          SuSEFirewall4Network.SetSshEnabled1stStage(false)
        when LINK_ENABLE_SSHD
          log.info "Enabling SSHD"
          SuSEFirewall4Network.SetSshdEnabled(true)
        when LINK_DISABLE_SSHD
          log.info "Disabling SSHD"
          SuSEFirewall4Network.SetSshdEnabled(false)
        when LINK_ENABLE_VNC
          log.info "Enabling VNC"
          SuSEFirewall4Network.SetVncEnabled1stStage(true)
        when LINK_DISABLE_VNC
          log.info "Disabling VNC"
          SuSEFirewall4Network.SetVncEnabled1stStage(false)
        when LINK_FIREWALL_DIALOG
          result = FirewallDialogSimple()
        else
          raise "INTERNAL ERROR: unknown action '#{@chosen_link}' for proposal client"
        end

        SuSEFirewallProposal.SetChangedByUser(true)

        adjust_configuration

        script_return = { "workflow_sequence" => result }
      when "Description"
        script_return = {
          # Proposal title
          "rich_text_title" => _("Firewall and SSH"),
          # Menu entry label
          "menu_title"      => _("&Firewall and SSH"),
          "id"              => LINK_FIREWALL_DIALOG
        }
      when "Write"
        script_return = { "success" => true }
      else
        log.error "Unknown command #{script_command}"
      end

      deep_copy(script_return)
    end

    def FirewallDialogSimple
      title = _("Basic Firewall and SSH Configuration")

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
                    Id(ID::ENABLE_FW),
                    Opt(:notify),
                    # TRANSLATORS: check-box label
                    _("Enable Firewall"),
                    SuSEFirewall4Network.Enabled1stStage
                  )
                ),

                Left(
                  CheckBox(
                    Id(ID::ENABLE_SSHD),
                    # TRANSLATORS: check-box label
                    _("Enable SSH Service"),
                    SuSEFirewall4Network.EnabledSshd
                  )
                ),

                sshd_port_ui,

                vnc_ports_ui
              )
            )
          )
        )
      )

      help = _(
        "<p><b><big>Firewall and SSH</big></b><br>\n" \
          "Firewall is a defensive mechanism that protects your computer from network attacks.\n" \
          "SSH is a service that allows logging into this computer remotely via dedicated\n" \
          "SSH client</p>"
      ) +
        _(
          "<p>Here you can choose whether the firewall will be enabled or disabled after\nthe installation. It is recommended to keep it enabled.</p>"
        ) +
        _(
          "<p>With enabled firewall, you can decide whether to open firewall port for SSH\n" \
            "service and allow remote SSH logins. Independently you can also enable SSH service (i.e. it\n" \
            "will be started on computer boot).</p>"
        ) + (
          if Linuxrc.vnc
            # TRANSLATORS: help text
            _(
              "<p>You can also open VNC ports in firewall. It will not enable\n" \
                "the remote administration service on a running system but it is\n" \
                "started by the installer automatically if needed.</p>"
            )
          else
            ""
          end
        )

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
        Id(ID::SSH_PORT),
        :Enabled,
        SuSEFirewall4Network.Enabled1stStage
      )
      UI.ChangeWidget(
        Id(ID::VNC_PORT),
        :Enabled,
        SuSEFirewall4Network.Enabled1stStage
      )

      dialog_ret = nil

      loop do
        dialog_ret = UI.UserInput
        enable_firewall = UI.QueryWidget(Id(ID::ENABLE_FW), :Value)

        if dialog_ret == ID::ENABLE_FW
          UI.ChangeWidget(Id(ID::SSH_PORT), :Enabled, enable_firewall)
          UI.ChangeWidget(Id(ID::VNC_PORT), :Enabled, enable_firewall)
          next
        elsif dialog_ret == :next || dialog_ret == :ok
          open_ssh_port = UI.QueryWidget(Id(ID::SSH_PORT), :Value)
          open_vnc_port = UI.QueryWidget(Id(ID::VNC_PORT), :Value)

          SuSEFirewall4Network.SetEnabled1stStage(enable_firewall)

          if enable_firewall
            SuSEFirewall4Network.SetSshEnabled1stStage(open_ssh_port)
            SuSEFirewall4Network.SetVncEnabled1stStage(open_vnc_port)
          end

          SuSEFirewall4Network.SetSshdEnabled(
            UI::QueryWidget(Id(ID::ENABLE_SSHD), :Value)
          )
        end

        # anything but enabling the firewall closes this dialog
        # (VNC and SSH checkboxes do nothing)
        break
      end

      Wizard.CloseDialog
      Convert.to_symbol(dialog_ret)
    end

  private

    def preformatted_proposal
      firewall_proposal = if SuSEFirewall4Network.Enabled1stStage
                            _(
                              "Firewall will be enabled (<a href=\"%s\">disable</a>)"
                            ) % LINK_DISABLE_FIREWALL
                          else
                            _(
                              "Firewall will be disabled (<a href=\"%s\">enable</a>)"
                            ) % LINK_ENABLE_FIREWALL
                          end

      sshd_proposal = if SuSEFirewall4Network.EnabledSshd
                        _(
                          "SSH service will be enabled (<a href=\"%s\">disable</a>)"
                        ) % LINK_DISABLE_SSHD
                      else
                        _(
                          "SSH service will be disabled (<a href=\"%s\">enable</a>)"
                        ) % LINK_ENABLE_SSHD
                      end

      # Filter proposals with content and sort them
      proposals = [firewall_proposal, ssh_fw_proposal, sshd_proposal, vnc_fw_proposal].compact
      "<ul>\n" + proposals.map { |prop| "<li>#{prop}</li>\n" }.join + "</ul>\n"
    end

    def sshd_port_ui
      return Empty() unless known_firewall_services?(SuSEFirewall4NetworkClass::SSH_SERVICES)

      Left(
        CheckBox(
          Id(ID::SSH_PORT),
          # TRANSLATORS: check-box label
          _("Open SSH Port"),
          SuSEFirewall4Network.EnabledSsh1stStage
        )
      )
    end

    def vnc_ports_ui
      return Empty() unless Linuxrc.vnc
      return Empty() unless known_firewall_services?(SuSEFirewall4NetworkClass::VNC_SERVICES)

      Left(
        CheckBox(
          Id(ID::VNC_PORT),
          # TRANSLATORS: check-box label
          _("Open &VNC Ports"),
          SuSEFirewall4Network.EnabledVnc1stStage
        )
      )
    end

    # Returns the VNC-port part of the firewall proposal description
    # Returns nil if this part should be skipped
    # @return [String] proposal html text
    def vnc_fw_proposal
      # It only makes sense to show the blocked ports if firewall is
      # enabled (bnc#886554)
      return nil unless SuSEFirewall4Network.Enabled1stStage
      return nil unless known_firewall_services?(SuSEFirewall4NetworkClass::VNC_SERVICES)
      # Show VNC port only if installing over VNC
      return nil unless Linuxrc.vnc

      if SuSEFirewall4Network.EnabledVnc1stStage
        _("VNC ports will be open (<a href=\"%s\">close</a>)") % LINK_DISABLE_VNC
      else
        _("VNC ports will be blocked (<a href=\"%s\">open</a>)") % LINK_ENABLE_VNC
      end
    end

    # Returns the SSH-port part of the firewall proposal description
    # Returns nil if this part should be skipped
    # @return [String] proposal html text
    def ssh_fw_proposal
      return nil unless SuSEFirewall4Network.Enabled1stStage
      return nil unless known_firewall_services?(SuSEFirewall4NetworkClass::SSH_SERVICES)

      if SuSEFirewall4Network.EnabledSsh1stStage
        _("SSH port will be open (<a href=\"%s\">block</a>)") % LINK_BLOCK_SSH_PORT
      else
        _("SSH port will be blocked (<a href=\"%s\">open</a>)") % LINK_OPEN_SSH_PORT
      end
    end

    # Returns true if all services are known to firewall
    # @param [Array <String>] services
    # @return [Boolean] if all are known
    def known_firewall_services?(services)
      @all_known_services ||= SuSEFirewallServices.all_services.keys

      (services - @all_known_services).empty?
    end

    # Reads and adjust the configuration for SuSEfirewall2 according to the current proposal.
    # bnc#887406: This needs to be done before user exports any configuration
    # to AutoYast profile.
    def adjust_configuration
      enable_fw = SuSEFirewall4Network.Enabled1stStage
      enable_sshd = SuSEFirewall4Network.EnabledSshd
      open_ssh_port = SuSEFirewall4Network.EnabledSsh1stStage
      open_vnc_port = SuSEFirewall4Network.EnabledVnc1stStage

      log.info "After installation, firewall will be #{enable_fw ? "enabled" : "disabled"}, " \
        "SSHD will be #{enable_sshd ? "enabled" : "disabled"}, " \
        "SSH port will be #{open_ssh_port ? "open" : "closed"}, " \
        "VNC port will be #{open_vnc_port ? "open" : "closed"}"

      # Read the configuration from sysconfig
      # bnc#887406: The file is in inst-sys
      previous_state = Progress.set(false)
      SuSEFirewall.Read
      Progress.set(previous_state)

      SuSEFirewall.SetEnableService(enable_fw)
      SuSEFirewall.SetStartService(enable_fw)

      # Request needed packages to be installed
      # bnc#893126
      if enable_fw
        PackagesProposal.AddResolvables(PROPOSAL_ID, :package, [SuSEFirewall.FIREWALL_PACKAGE])
      else
        PackagesProposal.RemoveResolvables(PROPOSAL_ID, :package, [SuSEFirewall.FIREWALL_PACKAGE])
      end

      if enable_sshd
        PackagesProposal.AddResolvables(PROPOSAL_ID, :package, [SuSEFirewall4NetworkClass::SSH_PACKAGE])
      else
        PackagesProposal.RemoveResolvables(PROPOSAL_ID, :package, [SuSEFirewall4NetworkClass::SSH_PACKAGE])
      end

      # Open or close FW ports depending on user decision
      # This can raise an exception if requested service-files are not part of the current system
      # For that reason, these files have to be part of the inst-sys
      if known_firewall_services?(SuSEFirewall4NetworkClass::SSH_SERVICES)
        SuSEFirewall.SetServicesForZones(
          SuSEFirewall4NetworkClass::SSH_SERVICES,
          SuSEFirewall.GetKnownFirewallZones,
          open_ssh_port
        )
      else
        log.warn "Services #{SuSEFirewall4NetworkClass::SSH_SERVICES} are unknown"
      end

      if known_firewall_services?(SuSEFirewall4NetworkClass::VNC_SERVICES)
        SuSEFirewall.SetServicesForZones(
          SuSEFirewall4NetworkClass::VNC_SERVICES,
          SuSEFirewall.GetKnownFirewallZones,
          open_vnc_port
        )
      else
        log.warn "Services #{SuSEFirewall4NetworkClass::VNC_SERVICES} are unknown"
      end

      # BNC #766300 - Automatically propose opening iscsi-target port
      # when installing with withiscsi=1
      SuSEFirewallProposal.propose_iscsi if Linuxrc.useiscsi

      # Writing the configuration including adjusting services
      # is done in firewall_stage1_finish
    end
  end unless defined? FirewallStage1ProposalClient
end

Yast::FirewallStage1ProposalClient.new.main
