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
# Copyright 2004, Novell, Inc.  All rights reserved.
#
# File:	modules/SuSEFirewall4Network.ycp
# Package:	Network Configuration
# Summary:	Module for handling interfaces in SuSEfirewall2
# Authors:	Lukas Ocilka <locilka@suse.cz>
#
#
# Module for handling network interfaces in SuSEfirewall2 using SuSEFirewall
# module.
require "yast"

module Yast
  class SuSEFirewall4NetworkClass < Module
    include Yast::Logger

    SSH_PACKAGE = "openssh".freeze
    SSH_SERVICES = ["service:sshd"].freeze
    VNC_SERVICES = ["service:vnc-httpd", "service:vnc-server"].freeze

    def main
      textdomain "network"

      Yast.import "SuSEFirewall"
      Yast.import "SuSEFirewallProposal"
      Yast.import "Stage"
      Yast.import "ServicesProposal"
      Yast.import "Linuxrc"
      Yast.import "ProductFeatures"
      Yast.import "Pkg"

      @firewall_enabled_1st_stage = false
      @ssh_enabled_1st_stage = false
      @sshd_enabled = false
      @vnc_enabled_1st_stage = false
    end

    # Function reads configuration of SuSEFirewall.
    #
    # @return	[Boolean] if successful
    def Read
      Builtins.y2milestone("Reading the firewall configuration")
      SuSEFirewall.Read
    end

    # Function writes configuration of SuSEFirewall.
    #
    # @return	[Boolean] if successful
    def Write
      Builtins.y2milestone("Writing the firewall configuration")
      SuSEFirewall.Write
    end

    # @return [Boolean] whether enabled and started
    def IsOn
      SuSEFirewall.GetEnableService && SuSEFirewall.GetStartService
    end

    # Sets the values of the initial proposal based on the product features,
    # the packages selected for installation and the installation method
    def prepare_proposal
      # variables from control file
      default_firewall = ProductFeatures.GetBooleanFeature("globals", "enable_firewall")
      default_fw_ssh = ProductFeatures.GetBooleanFeature("globals", "firewall_enable_ssh")
      default_sshd = ProductFeatures.GetBooleanFeature("globals", "enable_sshd")

      log.info "Default firewall values: enable_firewall=#{default_firewall}, "\
               "enable_ssh=#{default_fw_ssh}, enable_sshd=#{default_sshd}"

      # Enabling SuSEFirewall only makes sense if it's going to be
      # installed (bnc#881250)
      if Pkg.IsSelected(SuSEFirewall.FIREWALL_PACKAGE)
        SuSEFirewall4Network.SetEnabled1stStage(default_firewall)
      else
        SuSEFirewall4Network.SetEnabled1stStage(false)
      end

      # we're installing over SSH, propose opening SSH port (bnc#535206)
      if Linuxrc.usessh
        SuSEFirewall4Network.SetSshEnabled1stStage(true)
        SuSEFirewall4Network.SetSshdEnabled(true)
      else
        SuSEFirewall4Network.SetSshEnabled1stStage(default_fw_ssh)
        SuSEFirewall4Network.SetSshdEnabled(default_sshd)
      end

      # we're installing over VNC, propose opening VNC port (bnc#734264)
      SuSEFirewall4Network.SetVncEnabled1stStage(true) if Linuxrc.vnc
    end

    # Function returns list of items for combo box with all known
    # firewall zones.
    # There's also an item for "" (no zone or fw off).
    #
    # @return	item list for CWM
    def FirewallZonesComboBoxItems
      list_items = []
      protected_from_internal = SuSEFirewall.GetProtectFromInternalZone
      nozone = if IsOn()
        # item in combo box Firewall Zone
        _("Automatically Assigned Zone")
      else
        # item in combo box Firewall Zone
        _("Firewall Disabled")
      end
      list_items = Builtins.add(list_items, ["", nozone])

      # Listing all known zones
      Builtins.foreach(SuSEFirewall.GetKnownFirewallZones) do |zone_shortname|
        # Getting zone name for zone
        # Informing user about Unprotected inetrnal zone
        zone_name = Ops.add(
          SuSEFirewall.GetZoneFullName(zone_shortname),
          if zone_shortname == "INT" && !protected_from_internal
            # TRANSLATORS: Part of combo box item -> "Internal Zone (Unprotected)"
            " " + _("(Unprotected)")
          else
            ""
          end
        )
        list_items = Builtins.add(list_items, [zone_shortname, zone_name])
      end

      deep_copy(list_items)
    end

    # Function returns if interface is protected by firewall.
    # It means: Firewall is Running and Enabled. Interface is included
    # in any protected firewall zone (means EXT, DMZ or INT).
    #
    # @param [String] interface
    # @return	[Boolean] if it is protected
    def IsProtectedByFirewall(interface)
      interface_zone = SuSEFirewall.GetZoneOfInterface(interface)

      # interface is mentioned in uprotected zone
      if interface_zone == "INT" && !SuSEFirewall.GetProtectFromInternalZone
        Builtins.y2warning(
          "Interface '%1' is mentioned in uprotected zone '%2'",
          interface,
          "INT"
        )
      end

      # firewall must be running and enabled, interface must be in any zone
      IsOn() && !interface_zone.nil?
    end

    # Function returns the firewall zone of interface, "" if no zone includes
    # the interface. Error is reported when interface is found in multiple
    # firewall zones, then the first appearance is returned.
    # If firewall is off, "" is returned.
    #
    # @param [String] interface
    # @return	[String] zone
    def GetZoneOfInterface(interface)
      return "" if !IsOn()
      zoi = SuSEFirewall.GetZoneOfInterface(interface)
      zoi.nil? ? "" : zoi
    end

    # Returns whether any network interfaces are handled firewall either
    # explicitly mentioning them in any firewall zone or implicitly
    # by using string 'any' in firewall zones that would assign any interface
    # unassigned to any zone to that zone as a fallback.
    #
    # @return [Boolean] if any interface is handled by firewall
    def AnyInterfacesHandledByFirewall
      interfaces = []

      Builtins.foreach(SuSEFirewall.GetKnownFirewallZones) do |zone|
        interfaces = Convert.convert(
          Builtins.union(
            interfaces,
            SuSEFirewall.GetInterfacesInZoneSupportingAnyFeature(zone)
          ),
          from: "list",
          to:   "list <string>"
        )
      end

      Ops.greater_than(Builtins.size(interfaces), 0)
    end

    # Checks if interface of given name is assigned to given FW zone
    def iface_in_zone?(interface, zone)
      SuSEFirewall.GetInterfacesInZone(zone).include?(interface)
    end

    # Enables and starts fw service
    def start_fw_service
      SuSEFirewall.SetEnableService(true)
      SuSEFirewall.SetStartService(true)
    end

    # Disables and stops fw service
    def stop_fw_service
      SuSEFirewall.SetEnableService(false)
      SuSEFirewall.SetStartService(false)
    end

    # Functions sets protection of interface by the protect-status.<br>
    # protect==true  -> add interface into selected firewall zone, sets firewall
    #			 to be started and enabled when booting.<br>
    # protect==false -> removes interface from all firewall zones, if there
    #			 are no other interfaces protected by firewall, stops it
    #			 and removes it from boot process.
    #
    # @param [String] interface
    # @param [String] zone (makes sense for protect_status==true)
    # @param [Boolean] protect_status
    # @return	[Boolean] if successful
    def ProtectByFirewall(interface, zone, protect_status)
      # Adding protection
      if protect_status
        log.info("Enabling firewall because of '#{interface}' interface")

        SuSEFirewall.AddInterfaceIntoZone(interface, zone) if !iface_in_zone?(interface, zone)

        start_fw_service
      # Removing protection
      else
        # removing from all known zones
        zones = SuSEFirewall.GetKnownFirewallZones.select { |fw_zone| iface_in_zone?(interface, fw_zone) }
        zones.each do |remove_from_zone|
          SuSEFirewall.RemoveInterfaceFromZone(interface, remove_from_zone)
        end
        # if there are no other interfaces in configuration, stop firewall
        # and remove it from boot process
        if !AnyInterfacesHandledByFirewall()
          log.info("Disabling firewall, no interfaces are protected.")
          stop_fw_service
        end
      end

      true
    end

    # @return Whether the UI should warn about interfaces
    # that are not in any zone
    def UnconfiguredIsBlocked
      !SuSEFirewall.IsAnyNetworkInterfaceSupported
    end

    # Function sets that a firewall proposal was changed by user
    # by editing firewall zone of network interface
    # (applicable during 2nd stage of installation only)
    # @param boolean whether proposal was changed by user
    def ChangedByUser(changed)
      SuSEFirewallProposal.SetChangedByUser(changed) if Stage.cont

      nil
    end

    # Returns whether the firewall package is installed
    # @return [Boolean] if installed
    def IsInstalled
      SuSEFirewall.SuSEFirewallIsInstalled
    end

    # Sets whether firewall should be enabled
    # @param boolean new state
    def SetEnabled1stStage(enabled)
      @firewall_enabled_1st_stage = enabled

      nil
    end

    # Returns whether firewall is supposed to be enabled
    # @return [Boolean] whether enabled
    def Enabled1stStage
      @firewall_enabled_1st_stage
    end

    # Sets whether SSH port should be opened in firewall
    # @param boolean new state
    def SetSshEnabled1stStage(enabled)
      @ssh_enabled_1st_stage = enabled

      nil
    end

    # Returns whether SSH port is supposed to be open in firewall
    def EnabledSsh1stStage
      @ssh_enabled_1st_stage
    end

    # Sets whether start sshd
    # @param boolean new state
    def SetSshdEnabled(enabled)
      @sshd_enabled = enabled

      # bnc#887688 Needed for AutoYast export functionality at the end
      # of installation (clone_finish)
      if enabled
        ServicesProposal.enable_service("sshd")
      else
        ServicesProposal.disable_service("sshd")
      end

      nil
    end

    # Returns whether sshd will be enabled
    def EnabledSshd
      @sshd_enabled
    end

    # Sets whether VNC ports should be opened in firewall
    # @param boolean new state
    def SetVncEnabled1stStage(enabled)
      @vnc_enabled_1st_stage = enabled

      nil
    end

    # Returns whether VNC ports are supposed to be open in firewall
    def EnabledVnc1stStage
      @vnc_enabled_1st_stage
    end

    publish function: :Read, type: "boolean ()"
    publish function: :Write, type: "boolean ()"
    publish function: :IsOn, type: "boolean ()"
    publish function: :FirewallZonesComboBoxItems, type: "list <list <string>> ()"
    publish function: :IsProtectedByFirewall, type: "boolean (string)"
    publish function: :GetZoneOfInterface, type: "string (string)"
    publish function: :ProtectByFirewall, type: "boolean (string, string, boolean)"
    publish function: :UnconfiguredIsBlocked, type: "boolean ()"
    publish function: :ChangedByUser, type: "void (boolean)"
    publish function: :IsInstalled, type: "boolean ()"
    publish function: :SetEnabled1stStage, type: "void (boolean)"
    publish function: :Enabled1stStage, type: "boolean ()"
    publish function: :SetSshEnabled1stStage, type: "void (boolean)"
    publish function: :EnabledSsh1stStage, type: "boolean ()"
    publish function: :SetSshdEnabled, type: "void (boolean)"
    publish function: :EnabledSshd, type: "boolean ()"
    publish function: :SetVncEnabled1stStage, type: "void (boolean)"
    publish function: :EnabledVnc1stStage, type: "boolean ()"
  end

  SuSEFirewall4Network = SuSEFirewall4NetworkClass.new
  SuSEFirewall4Network.main
end
