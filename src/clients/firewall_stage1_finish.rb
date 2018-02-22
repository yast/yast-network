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
# File:	clients/firewall_stage1_finish.ycp
# Summary:	Installation client for writing firewall configuration
#		at the end of 1st stage
# Author:	Bubli <kmachalkova@suse.cz>
#
require "yast"

module Yast
  class FirewallStage1FinishClient < Client
    def main
      textdomain "network"

      Yast.import "Mode"
      Yast.import "Service"
      Yast.import "SuSEFirewall"
      Yast.import "SuSEFirewallServices"
      Yast.import "SuSEFirewall4Network"
      Yast.import "SuSEFirewallProposal"

      @ret = nil
      @func = ""
      @param = {}

      # Check arguments
      if Ops.greater_than(Builtins.size(WFM.Args), 0) &&
          Ops.is_string?(WFM.Args(0))
        @func = Convert.to_string(WFM.Args(0))
        if Ops.greater_than(Builtins.size(WFM.Args), 1) &&
            Ops.is_map?(WFM.Args(1))
          @param = Convert.to_map(WFM.Args(1))
        end
      end

      Builtins.y2milestone("starting firewall_stage1_finish")
      Builtins.y2debug("func=%1", @func)
      Builtins.y2debug("param=%1", @param)

      case @func
      when "Info"
        return {
          "steps" => 1,
          # progress step title
          "title" => _(
            "Writing Firewall Configuration..."
          ),
          "when"  => [:installation, :autoinst]
        }
      when "Write"
        # The Autoyast configuration is mainly done during the second stage but
        # we need to open remote services if enabled by linuxrc (bsc#1080630)
        if Mode.autoinst && SuSEFirewall4Network.IsInstalled
          Builtins.y2milestone("Preparing proposal for autoconfiguration.")
          SuSEFirewall4Network.prepare_proposal unless SuSEFirewallProposal.GetChangedByUser
          adjust_configuration
        end

        # Enable SSH service independent of port open (bnc#865056)
        Service.Enable("sshd") if SuSEFirewall4Network.EnabledSshd

        # This is equivalent to write-only, do not attempt to restart the service
        SuSEFirewall.WriteConfiguration
      else
        Builtins.y2error("unknown function: %1", @func)
        @ret = nil
      end

      Builtins.y2debug("ret=%1", @ret)
      Builtins.y2milestone("firewall_stage1_finish finished")
      deep_copy(@ret)
    end

    # Returns true if all services are known to firewall
    # @param [Array <String>] services
    # @return [Boolean] if all are known
    def known_firewall_services?(services)
      @all_known_services ||= SuSEFirewallServices.all_services.keys

      (services - @all_known_services).empty?
    end

    # Reads and adjust the configuration for SuSEfirewall2 according to the current proposal.
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
    end
  end
end

Yast::FirewallStage1FinishClient.new.main
