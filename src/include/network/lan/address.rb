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
# File:	include/network/lan/address.ycp
# Package:	Network configuration
# Summary:	Network card adresss configuration dialogs
# Authors:	Michal Svec <msvec@suse.cz>
#
require "y2firewall/helpers/interfaces"
require "y2network/dialogs/edit_interface"

module Yast
  module NetworkLanAddressInclude
    include Y2Firewall::Helpers::Interfaces
    include Yast::Logger
    include Yast::I18n

    def initialize_network_lan_address(include_target)
      Yast.import "UI"

      textdomain "network"

      Yast.import "Host"
      Yast.import "Lan"
      Yast.import "NetworkInterfaces"
      Yast.import "ProductFeatures"
      Yast.import "String"

      Yast.include include_target, "network/summary.rb"
      Yast.include include_target, "network/lan/help.rb"
      Yast.include include_target, "network/lan/hardware.rb"
      Yast.include include_target, "network/complex.rb"
      Yast.include include_target, "network/lan/bridge.rb"
      Yast.include include_target, "network/lan/s390.rb"

      @settings = {}

      @force_static_ip = ProductFeatures.GetBooleanFeature(
        "network",
        "force_static_ip"
      )
    end

    # Dialog for setting up IP address
    # @return dialog result
    def AddressDialog
      initialize_address_settings

      ret = Y2Network::Dialogs::EditInterface.run(@settings)

      Builtins.y2milestone("ShowAndRun: %1", ret)

      if ret != :back && ret != :abort
        # general tab
        NetworkInterfaces.Name = @settings["IFCFGID"]
        # LanItems.device modification is ignored
        LanItems.Items[LanItems.current]["ifcfg"] = @settings["IFCFGID"]
        LanItems.startmode = Ops.get_string(@settings, "STARTMODE", "")
        LanItems.mtu = Ops.get_string(@settings, "MTU", "")
        # TODO: handle nicer firewall zone. Probably in builder?
        # LanItems.firewall_zone = firewall_zone.store_permanent if firewalld.installed?
        LanItems.ifplugd_priority = @settings["IFPLUGD_PRIORITY"]

        # address tab
        bootproto = @settings.fetch("BOOTPROTO", "")
        ipaddr = @settings.fetch("IPADDR", "")

        # IP is mandatory for static configuration. Makes no sense to write static
        # configuration without that.
        return ret if bootproto == "static" && ipaddr.empty?

        LanItems.bootproto = bootproto

        if bootproto == "static"
          update_hostname(ipaddr, @settings.fetch("HOSTNAME", ""))

          LanItems.ipaddr = ipaddr
          LanItems.netmask = Ops.get_string(@settings, "NETMASK", "")
          LanItems.prefix = Ops.get_string(@settings, "PREFIXLEN", "")
          LanItems.remoteip = Ops.get_string(@settings, "REMOTEIP", "")
        else
          LanItems.ipaddr = ""
          LanItems.netmask = ""
          LanItems.remoteip = ""
          # fixed bug #73739 - if dhcp is used, dont set default gw statically
          # but also: reset default gw only if DHCP* is used, this branch covers
          #		 "No IP address" case, then default gw must stay (#460262)
          # and also: don't delete default GW for usb/pcmcia devices (#307102)
          if LanItems.isCurrentDHCP && !LanItems.isCurrentHotplug
            yast_config = Y2Network::Config.find(:yast)
            yast_config.routing.remove_default_routes if yast_config
          end
        end

        # When virtual interfaces are added the list of routing devices needs
        # to be updated to offer them
        LanItems.add_current_device_to_routing if LanItems.update_routing_devices?
      end

      if LanItems.type == "vlan"
        LanItems.vlan_etherdevice = Ops.get_string(@settings, "ETHERDEVICE", "")
        LanItems.vlan_id = Builtins.tostring(
          Ops.get_integer(@settings, "VLAN_ID", 0)
        )
      elsif LanItems.type == "br"
        LanItems.bridge_ports = @settings["BRIDGE_PORTS"].join(" ")
        log.info "bridge ports stored as #{LanItems.bridge_ports.inspect}"
      elsif LanItems.type == "bond"
        new_slaves = @settings.fetch("SLAVES", []).select { |s| !LanItems.bond_slaves.include? s }
        LanItems.bond_slaves = @settings["SLAVES"]
        LanItems.bond_option = @settings["BONDOPTION"]
        Lan.autoconf_slaves = (Lan.autoconf_slaves + new_slaves).uniq.sort
        log.info "bond settings #{LanItems.bond_slaves}"
      elsif Builtins.contains(["tun", "tap"], LanItems.type)
        LanItems.tunnel_set_owner = Ops.get_string(
          @settings,
          "TUNNEL_SET_OWNER",
          ""
        )
        LanItems.tunnel_set_group = Ops.get_string(
          @settings,
          "TUNNEL_SET_GROUP",
          ""
        )
      end

      LanItems.Rollback if ret != :next

      # proceed with WLAN settings if appropriate, #42420
      ret = :wire if ret == :next && LanItems.type == "wlan"

      deep_copy(ret)
    end

  private

    # Initializes the Address Dialog @settings with the corresponding LanItems values
    def initialize_address_settings
      @settings.replace( # general tab:
        "STARTMODE"        => LanItems.startmode,
        "IFPLUGD_PRIORITY" => LanItems.ifplugd_priority,
        # problems when renaming the interface?
        "MTU"              => LanItems.mtu,
        "FWZONE"           => LanItems.firewall_zone,
        # address tab:
        "BOOTPROTO"        => LanItems.bootproto,
        "IPADDR"           => LanItems.ipaddr,
        "NETMASK"          => LanItems.netmask,
        "PREFIXLEN"        => LanItems.prefix,
        "REMOTEIP"         => LanItems.remoteip,
        "HOSTNAME"         => initial_hostname(LanItems.ipaddr),
        "IFCFGTYPE"        => LanItems.type,
        "IFCFGID"          => LanItems.device
      )

      if LanItems.type == "vlan"
        @settings["ETHERDEVICE"] = LanItems.vlan_etherdevice
        @settings["VLAN_ID"]     = LanItems.vlan_id.to_i
      elsif LanItems.type == "br"
        ports = LanItems.bridge_ports
        ports = Yast::NetworkInterfaces.Current["BRIDGE_PORTS"] || "" if ports.empty?
        log.info "ports #{ports.inspect}"
        @settings["BRIDGE_PORTS"] = ports.split
      elsif LanItems.type == "bond"
        @settings["BONDOPTION"] = Yast::LanItems.bond_option
        @settings["SLAVES"] = Yast::LanItems.bond_slaves || []
      end

      if ["tun", "tap"].include?(LanItems.type)
        @settings.replace("BOOTPROTO"        => "static",
                          "STARTMODE"        => "auto",
                          "TUNNEL"           => LanItems.type,
                          "TUNNEL_SET_OWNER" => LanItems.tunnel_set_owner,
                          "TUNNEL_SET_GROUP" => LanItems.tunnel_set_group)
      end

      # #65524
      @settings["BOOTPROTO"] = "static" if LanItems.operation == :add && @force_static_ip

      log.info "settings after init #{@settings.inspect}"
    end

    # Performs hostname update
    #
    # This handles ip and hostname change when editing NIC properties.
    # The method relies on old NIC's IP which is set globally at initialization
    # of NIC edit dialog (@see LanItems#ipaddr)
    #
    # When hostname is empty, then old IP's record is cleared from /etc/hosts and
    # new is not created.
    # Otherwise the canonical name and all aliases in the record
    # are replaced by new ones.
    #
    # @param ipaddr [String] ip address
    # @param hostname [String] new hostname
    def update_hostname(ipaddr, hostname)
      ip_changed = LanItems.ipaddr != ipaddr
      initial_hostname = initial_hostname(LanItems.ipaddr)
      hostname_changed = initial_hostname != hostname

      return if !(ip_changed || hostname_changed || hostname.empty?)

      # store old names, remove the record
      names = Host.names(LanItems.ipaddr).first
      Host.remove_ip(LanItems.ipaddr)

      if ip_changed && !hostname_changed && !names.nil?
        log.info("Dropping record for #{LanItems.ipaddr} from /etc/hosts")

        Host.add_name(ipaddr, names)
      end
      if !hostname.empty? && hostname_changed
        log.info("Updating cannonical name for #{LanItems.ipaddr} in /etc/hosts")

        Host.Update(initial_hostname, hostname, ipaddr)
      end

      nil
    end

    # Returns canonical hostname for the given ip
    def initial_hostname(ipaddr)
      host_list = Host.names(ipaddr)
      if Ops.greater_than(Builtins.size(host_list), 1)
        Builtins.y2milestone(
          "More than one hostname for single IP detected, using the first one only"
        )
      end

      String.FirstChunk(Ops.get(host_list, 0, ""), " \t")
    end
  end
end
