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
require "y2network/widgets/additional_addresses"
require "y2network/widgets/blink_button"
require "y2network/widgets/bond_options"
require "y2network/widgets/bond_slave"
require "y2network/widgets/boot_protocol"
require "y2network/widgets/bridge_ports"
require "y2network/widgets/ethtools_options"
require "y2network/widgets/firewall_zone"
require "y2network/widgets/ifplugd_priority"
require "y2network/widgets/interface_name"
require "y2network/widgets/ip_address"
require "y2network/widgets/ipoib_mode"
require "y2network/widgets/kernel_module"
require "y2network/widgets/kernel_options"
require "y2network/widgets/mtu"
require "y2network/widgets/netmask"
require "y2network/widgets/remote_ip"
require "y2network/widgets/s390_button"
require "y2network/widgets/startmode"
require "y2network/widgets/tunnel"
require "y2network/widgets/udev_rules"
require "y2network/widgets/vlan_id"
require "y2network/widgets/vlan_interface"

module Yast
  module NetworkLanAddressInclude
    include Y2Firewall::Helpers::Interfaces
    include Yast::Logger
    include Yast::I18n

    def initialize_network_lan_address(include_target)
      Yast.import "UI"

      textdomain "network"

      Yast.import "CWM"
      Yast.import "CWMTab"
      Yast.import "DNS"
      Yast.import "Host"
      Yast.import "Hostname"
      Yast.import "IP"
      Yast.import "Label"
      Yast.import "Lan"
      Yast.import "Netmask"
      Yast.import "NetHwDetection"
      Yast.import "NetworkInterfaces"
      Yast.import "Popup"
      Yast.import "ProductFeatures"
      Yast.import "String"
      Yast.import "Wizard"
      Yast.import "Map"

      Yast.include include_target, "network/summary.rb"
      Yast.include include_target, "network/lan/help.rb"
      Yast.include include_target, "network/lan/hardware.rb"
      Yast.include include_target, "network/complex.rb"
      Yast.include include_target, "network/widgets.rb"
      Yast.include include_target, "network/lan/bridge.rb"
      Yast.include include_target, "network/lan/s390.rb"

      @settings = {}

      @force_static_ip = ProductFeatures.GetBooleanFeature(
        "network",
        "force_static_ip"
      )
    end

    def additional_addresses
      @additional_addresses ||= Y2Network::Widgets::AdditionalAddresses.new(@settings)
    end

    def tunnel_widget
      @tunnel_widget ||= Y2Network::Widgets::Tunnel.new(@settings)
    end

    def kernel_module_widget
      @kernel_module_widget ||= Y2Network::Widgets::KernelModule.new(@settings)
    end

    def kernel_options_widget
      @kernel_options_widget ||= Y2Network::Widgets::KernelOptions.new(@settings)
    end

    def udev_rules_widget
      @udev_rules_widget ||= Y2Network::Widgets::UdevRules.new(@settings)
    end

    def vlan_id_widget
      @vlan_id_widget ||= Y2Network::Widgets::VlanID.new(@settings)
    end

    def ethtools_options_widget
      @ethtools_options_widget ||= Y2Network::Widgets::EthtoolsOptions.new(@settings)
    end

    def remote_ip_widget
      @remote_ip_widget ||= Y2Network::Widgets::RemoteIP.new(@settings)
    end

    def vlan_interface_widget
      @vlan_interface_widget ||= Y2Network::Widgets::VlanInterface.new(@settings)
    end

    def blink_button
      @blink_button ||= Y2Network::Widgets::BlinkButton.new(@settings)
    end

    def bond_slave_widget
      @bond_slave_widget ||= Y2Network::Widgets::BondSlave.new(@settings)
    end

    def bond_options_widget
      @bond_options_widget ||= Y2Network::Widgets::BondOptions.new(@settings)
    end

    def bridge_ports_widget
      @bridge_ports_widget ||= Y2Network::Widgets::BridgePorts.new(@settings)
    end

    def mtu_widget
      @mtu_widget ||= Y2Network::Widgets::MTU.new(@settings)
    end

    def netmask_widget
      @netmask_widget ||= Y2Network::Widgets::Netmask.new(@settings)
    end

    def interface_name_widget
      @interface_name_widget ||= Y2Network::Widgets::InterfaceName.new(@settings)
    end

    def ip_address_widget
      @ip_address_widget ||= Y2Network::Widgets::IPAddress.new(@settings)
    end

    def ipoib_mode_widget
      @ipoib_mode_widget ||= Y2Network::Widgets::IPoIBMode.new(@settings)
    end

    def ifplugd_priority_widget
      @ifplugd_priority_widget ||= Y2Network::Widgets::IfplugdPriority.new(@settings)
    end

    def startmode_widget
      @startmode_widget ||= Y2Network::Widgets::Startmode.new(@settings, ifplugd_priority_widget)
    end

    def s390_button
      @s390_button ||= Y2Network::Widgets::S390Button.new
    end

    def boot_protocol_widget
      @boot_protocol_widget ||= Y2Network::Widgets::BootProtocol.new(@settings)
    end

    def widget_descr_local
      res = {
        additional_addresses.widget_id    => additional_addresses.cwm_definition,
        interface_name_widget.widget_id   => interface_name_widget.cwm_definition,
        ethtools_options_widget.widget_id => ethtools_options_widget.cwm_definition,
        mtu_widget.widget_id              => mtu_widget.cwm_definition,
        netmask_widget.widget_id          => netmask_widget.cwm_definition,
        tunnel_widget.widget_id           => tunnel_widget.cwm_definition,
        bridge_ports_widget.widget_id     => bridge_ports_widget.cwm_definition,
        blink_button.widget_id            => blink_button.cwm_definition,
        ip_address_widget.widget_id       => ip_address_widget.cwm_definition,
        ipoib_mode_widget.widget_id       => ipoib_mode_widget.cwm_definition,
        vlan_id_widget.widget_id          => vlan_id_widget.cwm_definition,
        vlan_interface_widget.widget_id   => vlan_interface_widget.cwm_definition,
        kernel_module_widget.widget_id    => kernel_module_widget.cwm_definition,
        kernel_options_widget.widget_id   => kernel_options_widget.cwm_definition,
        udev_rules_widget.widget_id       => udev_rules_widget.cwm_definition,
        bond_slave_widget.widget_id       => bond_slave_widget.cwm_definition,
        bond_options_widget.widget_id     => bond_options_widget.cwm_definition,
        boot_protocol_widget.widget_id    => boot_protocol_widget.cwm_definition,
        remote_ip_widget.widget_id        => remote_ip_widget.cwm_definition,
        startmode_widget.widget_id        => startmode_widget.cwm_definition,
        ifplugd_priority_widget.widget_id => ifplugd_priority_widget.cwm_definition,
        # leftovers
        s390_button.widget_id             => s390_button.cwm_definition
      }

      res
    end

    def general_tab
      type = @settings["IFCFGTYPE"]

      {
        "header"   => _("&General"),
        "contents" => MarginBox(
          1,
          0,
          VBox(
            MarginBox(
              1,
              0,
              VBox(
                # FIXME: udev rules for anything without hwinfo is wrong
                LanItems.operation == :add ? interface_name_widget.widget_id : udev_rules_widget.widget_id,
                Frame(
                  _("Device Activation"),
                  HBox(startmode_widget.widget_id, ifplugd_priority_widget.widget_id, HStretch())
                ),
                VSpacing(0.4),
                Frame(_("Firewall Zone"), HBox("FWZONE", HStretch())),
                VSpacing(0.4),
                type == "ib" ? HBox(ipoib_mode_widget.widget_id) : Empty(),
                type == "ib" ? VSpacing(0.4) : Empty(),
                Frame(
                  _("Maximum Transfer Unit (MTU)"),
                  HBox(mtu_widget.widget_id, HStretch())
                ),
                VStretch()
              )
            )
          )
        ),
        # FIXME: we have helps per widget and for the whole
        # tab set but not for one tab
        "help"     => _(
          "<p>Configure the detailed network card settings here.</p>"
        )
      }
    end

    def address_tab
      # in case that ifcfg does not exist, /sys might not cointain
      # any device info (especially for virtual devices like vlan)
      # @type variable is already initialized by @see HardwareDialog
      # resp its storage handler @see storeHW
      type = @builder.type

      drvtype = DriverType(type)
      is_ptp = drvtype == "ctc" || drvtype == "iucv"
      # TODO: dynamic for dummy. or add dummy from outside?
      no_dhcp =
        is_ptp ||
        type == "dummy"

      address_p2p_contents = Frame(
        "", # labelless frame
        VBox(ip_address_widget.widget_id, remote_ip_widget.widget_id)
      )

      address_static_contents = Frame(
        "", # labelless frame
        VBox(
          ip_address_widget.widget_id,
          netmask_widget.widget_id,
          # TODO: new widget, add logic
          # "GATEWAY"
          Empty()
        )
      )

      address_dhcp_contents = VBox(boot_protocol_widget.widget_id)
      just_address_contents = if is_ptp
        address_p2p_contents
      elsif no_dhcp
        address_static_contents
      else
        address_dhcp_contents
      end

      label = HBox(
        type == "vlan" ? VBox(HBox(vlan_interface_widget.widget_id, vlan_id_widget.widget_id)) : Empty()
      )

      address_contents = if ["tun", "tap"].include?(type)
        VBox(Left(label), tunnel_widget.widget_id)
      else
        VBox(
          Left(label),
          just_address_contents,
          additional_addresses.widget_id
        )
      end

      {
        # FIXME: here it does not complain about missing
        # shortcuts
        "header"   => _("&Address"),
        "contents" => address_contents,
        # Address tab help
        "help"     => _("<p>Configure your IP address.</p>")
      }
    end

    def hardware_tab
      {
        "header"   => _("&Hardware"),
        "contents" => VBox(
          # FIXME: ensure that only eth, maybe also ib?
          @settings["IFCFGTYPE"] == "eth" ? blink_button.widget_id : Empty(),
          Frame(
            _("&Kernel Module"),
            HBox(
              HSpacing(0.5),
              VBox(
                VSpacing(0.4),
                HBox(
                  kernel_module_widget.widget_id, # Text entry label
                  HSpacing(0.5),
                  kernel_options_widget.widget_id
                ),
                VSpacing(0.4)
              ),
              HSpacing(0.5)
            )
          ),
          # FIXME: probably makes sense only for eth
          ethtools_options_widget.widget_id,
          VStretch()
        )
      }
    end

    def bond_slaves_tab
      {
        "header"   => _("&Bond Slaves"),
        "contents" => VBox(bond_slave_widget.widget_id, bond_options_widget.widget_id)
      }
    end

    def bridge_slaves_tab
      {
        "header"   => _("Bridged Devices"),
        "contents" => VBox(bridge_ports_widget.widget_id)
      }
    end

    def wireless_tab
      {
        "header"       => _("&Wireless"),
        "contents"     => Empty(),
        "widget_names" => []
      }
    end

    # Dialog for setting up IP address
    # @return dialog result
    def AddressDialog(builder:)
      @builder = builder
      initialize_address_settings(builder)

      wd = widget_descr_local

      @settings["IFCFG"] = builder.name if LanItems.operation != :add

      # Firewall config
      firewall_zone = Y2Network::Widgets::FirewallZone.new(builder.name)
      wd["FWZONE"] = firewall_zone.cwm_definition
      firewall_zone.value = @settings["FWZONE"] if firewalld.installed?

      functions = {
        abort: fun_ref(LanItems.method(:Rollback), "boolean ()")
      }

      wd_content = {
        "tab_order"          => ["t_general", "t_addr", "hardware"],
        "tabs"               => {
          "t_general"    => general_tab,
          "t_addr"       => address_tab,
          "hardware"     => hardware_tab,
          "bond_slaves"  => bond_slaves_tab,
          "bridge_ports" => bridge_slaves_tab,
          "t3"           => wireless_tab
        },
        "initial_tab"        => "t_addr",
        "widget_descr"       => wd,
        "tab_help"           => "",
        "fallback_functions" => functions
      }
      case builder.type
      when "vlan"
        wd_content["tab_order"] = ["t_general", "t_addr"]
      when "tun", "tap"
        wd_content["tab_order"] = ["t_addr"]
      when "br"
        wd_content["tab_order"] = ["t_general", "t_addr", "bridge_ports"]
      when "bond"
        wd_content["tab_order"] << "bond_slaves"
      end

      wd = Convert.convert(
        Builtins.union(wd, "tab" => CWMTab.CreateWidget(wd_content)),
        from: "map",
        to:   "map <string, map <string, any>>"
      )

      ret = CWM.ShowAndRun(
        "widget_names"       => ["tab"],
        "widget_descr"       => wd,
        "contents"           => HBox("tab"),
        # Address dialog caption
        "caption"            => _("Network Card Setup"),
        "back_button"        => Label.BackButton,
        "abort_button"       => Label.CancelButton,
        "next_button"        => Label.NextButton,
        "fallback_functions" => functions,
        "disable_buttons"    => if LanItems.operation != :add
                                  ["back_button"]
                                else
                                  []
                                end
      )
      Wizard.RestoreAbortButton

      Builtins.y2milestone("ShowAndRun: %1", ret)

      if ret != :back && ret != :abort
        # general tab
        builder.set(option: "STARTMODE", value: Ops.get_string(@settings, "STARTMODE", ""))
        builder.set(option: "MTU", value: Ops.get_string(@settings, "MTU", ""))
        builder.set(option: "ZONE", value: firewall_zone.store_permanent) if firewalld.installed?
        builder.set(option: "IFPLUGD_PRIORITY", value: @settings["IFPLUGD_PRIORITY"])

        # address tab
        bootproto = builder.option("BOOTPROTO")
        ipaddr = builder.option("IPADDR")

        # IP is mandatory for static configuration. Makes no sense to write static
        # configuration without that.
        return ret if bootproto == "static" && ipaddr.empty?

        builder.set(option: "BOOTPROTO", value: bootproto)

        if bootproto == "static"
          update_hostname(ipaddr, @settings.fetch("HOSTNAME", ""))

          builder.set(option: "IPADDR", value: ipaddr)
          builder.set(option: "NETMASK", value: Ops.get_string(@settings, "NETMASK", ""))
          builder.set(option: "PREFIXLEN", value: Ops.get_string(@settings, "PREFIXLEN", ""))
          builder.set(option: "REMOTEIP", value: Ops.get_string(@settings, "REMOTEIP", ""))
        else
          builder.set(option: "IPADDR", value: ipaddr)
          builder.set(option: "NETMASK", value: "")
          builder.set(option: "REMOTEIP", value: "")
          # fixed bug #73739 - if dhcp is used, dont set default gw statically
          # but also: reset default gw only if DHCP* is used, this branch covers
          #		 "No IP address" case, then default gw must stay (#460262)
          # and also: don't delete default GW for usb/pcmcia devices (#307102)
          # FIXME: not working in network-ng
          if LanItems.isCurrentDHCP && !LanItems.isCurrentHotplug
            yast_config = Y2Network::Config.find(:yast)
            yast_config.routing.remove_default_routes if yast_config
          end
        end

        # When virtual interfaces are added the list of routing devices needs
        # to be updated to offer them
        LanItems.add_current_device_to_routing if LanItems.update_routing_devices?
      end

      if builder.type == "vlan"
        builder.set(option: "ETHERDEVICE", value: Ops.get_string(@settings, "ETHERDEVICE", ""))
        builder.set(
          option: "VLANID",
          value:   Builtins.tostring(Ops.get_integer(@settings, "VLAN_ID", 0))
        )
      elsif builder.type == "br"
        builder.set(option: "BRIDGE_PORTS", value: @settings["BRIDGE_PORTS"].join(" "))
        log.info "bridge ports stored as #{builder.option("BRIDGE_PORTS")}"
      elsif builder.type == "bond"
        new_slaves = @settings.fetch("SLAVES", []).select do |s|
          # TODO: check initialization of "SLAVES"
          !builder.option("SLAVES").include? s
        end
        builder.set(option: "SLAVES", value: @settings["SLAVES"])
        builder.set(option: "BONDOPTION", value: @settings["BONDOPTION"])
        Lan.autoconf_slaves = (Lan.autoconf_slaves + new_slaves).uniq.sort
        log.info "bond settings #{builder.option("BONDOPTION")}"
      elsif ["tun", "tap"].include?(builder.type)
        builder.set(
          option: "TUNNEL_SET_OWNER",
          value:  Ops.get_string(@settings, "TUNNEL_SET_OWNER", "")
        )
        builder.set(
          option: "TUNNEL_SET_GROUP",
          value:  Ops.get_string(@settings, "TUNNEL_SET_GROUP", "")
        )
      end

      # proceed with WLAN settings if appropriate, #42420
      ret = :wire if ret == :next && builder.type == "wlan"

      ret
    end

  private

    # Initializes the Address Dialog @settings with the corresponding LanItems values
    def initialize_address_settings(builder)
      @settings.replace(
        # general tab:
        "STARTMODE"        => builder.option("STARTMODE"),
        "IFPLUGD_PRIORITY" => builder.option("IFPLUGD_PRIORITY"),
        # problems when renaming the interface?
        "MTU"              => builder.option("MTU"),
        "FWZONE"           => builder.option("FWZONE"),
        # address tab:
        "BOOTPROTO"        => builder.option("BOOTPROTO"),
        "IPADDR"           => builder.option("IPADDR"),
        "NETMASK"          => builder.option("NETMASK"),
        "PREFIXLEN"        => builder.option("PREFIXLEN"),
        "REMOTEIP"         => builder.option("REMOTEIP"),
        "HOSTNAME"         => initial_hostname(builder.option("IPADDR")),
        "IFCFGTYPE"        => builder.type,
        "IFCFGID"          => builder.name
      )

      if builder.type == "vlan"
        @settings["ETHERDEVICE"] = builder.option("ETHERDEVICE")
        @settings["VLAN_ID"]     = builder.option("VLAN_ID")
      elsif builder.type == "br"
        # FIXME: check / do proper initialization mainly for the edit workflow
        ports = builder.option("BRIDGE_PORTS")
        log.info "ports #{ports.inspect}"
        @settings["BRIDGE_PORTS"] = ports.split
      elsif builder.type == "bond"
        @settings["BONDOPTION"] = builder.option("BONDOPTION")
        @settings["SLAVES"] = builder.option("SLAVES")
      elsif ["tun", "tap"].include?(builder.type)
        @settings.replace(
          "BOOTPROTO"        => "static",
          "STARTMODE"        => "auto",
          "TUNNEL"           => builder.type,
          "TUNNEL_SET_OWNER" => builder.option("TUNNEL_SET_OWNER"),
          "TUNNEL_SET_GROUP" => builder.option("TUNNEL_SET_GROUP")
        )
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
