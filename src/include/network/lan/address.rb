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
require "y2network/widgets/boot_protocol"
require "y2network/widgets/firewall_zone"
require "y2network/widgets/tunnel"
require "y2network/widgets/bond_options"
require "y2network/widgets/bond_slave"
require "y2network/widgets/bridge_ports"
require "y2network/widgets/ifplugd_priority"
require "y2network/widgets/startmode"
require "y2network/widgets/mtu"

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
      Yast.include include_target, "network/lan/virtual.rb"
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

    def tunnel_widget
      @tunnel_widget ||= Y2Network::Widgets::Tunnel.new(@settings)
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

    def ifplugd_priority_widget
      @ifplugd_priority_widget ||= Y2Network::Widgets::IfplugdPriority.new(@settings)
    end

    def startmode_widget
      @startmode_widget ||= Y2Network::Widgets::Startmode.new(@settings, ifplugd_priority_widget)
    end

    def boot_protocol_widget
      @boot_protocol_widget ||= Y2Network::Widgets::BootProtocol.new(@settings)
    end

    def widget_descr_local
      res = {
        "AD_ADDRESSES"                 => {
          "widget"        => :custom,
          "custom_widget" => Frame(
            Id(:f_additional),
            # Frame label
            _("Additional Addresses"),
            HBox(
              HSpacing(3),
              VBox(
                # :-) this is a small trick to make ncurses in 80x25 happy :-)
                # it rounds spacing up or down to the nearest integer, 0.5 -> 1, 0.49 -> 0
                VSpacing(0.49),
                Table(
                  Id(:table),
                  Opt(:notify),
                  Header(
                    # Table header label
                    _("IPv4 Address Label"),
                    # Table header label
                    _("IP Address"),
                    # Table header label
                    _("Netmask")
                  ),
                  []
                ),
                Left(
                  HBox(
                    # PushButton label
                    PushButton(Id(:add), _("Ad&d")),
                    # PushButton label
                    PushButton(Id(:edit), Opt(:disabled), _("&Edit")),
                    # PushButton label
                    PushButton(Id(:delete), Opt(:disabled), _("De&lete"))
                  )
                ),
                VSpacing(0.49)
              ),
              HSpacing(3)
            )
          ),
          "help"          => Ops.get_string(@help, "additional", ""),
          "init"          => fun_ref(method(:initAdditional), "void (string)"),
          "handle"        => fun_ref(
            method(:handleAdditional),
            "symbol (string, map)"
          ),
          "store"         => fun_ref(
            method(:storeAdditional),
            "void (string, map)"
          )
        },
        "IFNAME"                       => {
          "widget" => :textentry,
          "label"  => _("&Name of Interface"),
          "opt"    => [:hstretch],
          "help"   => _("<p>TODO kind of vague!</p>")
        },
        mtu_widget.widget_id           => mtu_widget.cwm_definition,
        "IFCFGTYPE"                    => {
          "widget"            => :combobox,
          # ComboBox label
          "label"             => _("&Device Type"),
          "opt"               => [:hstretch, :notify],
          "help"              => "",
          # "items" will be filled in the dialog itself
          "init"              => fun_ref(
            method(:initIfcfg),
            "void (string)"
          )
        },
        "IFCFGID"                      => {
          "widget" => :textentry,
          # ComboBox label
          "label"  => _("&Configuration Name"),
          "opt"    => [:hstretch, :disabled],
          "help"   => "",
          "init"   => fun_ref(method(:initIfcfgId), "void (string)")
        },
        tunnel_widget.widget_id        => tunnel_widget.cwm_definition,
        bridge_ports_widget.widget_id  => bridge_ports_widget.cwm_definition,
        "ETHERDEVICE"                  => {
          "widget"        => :custom,
          "custom_widget" => HBox(
            ComboBox(
              Id(:vlan_eth),
              Opt(:notify),
              _("Real Interface for &VLAN"),
              []
            ),
            IntField(Id(:vlan_id), Opt(:notify), _("VLAN ID"), 0, 9999, 0)
          ),
          "opt"           => [:hstretch],
          "init"          => fun_ref(method(:InitVLANSlave), "void (string)"),
          "handle"        => fun_ref(
            method(:HandleVLANSlave),
            "symbol (string, map)"
          ),
          "store"         => fun_ref(
            method(:StoreVLANSlave),
            "void (string, map)"
          ),
          "help"          => Ops.get_string(@help, "etherdevice", "")
        },
        bond_slave_widget.widget_id    => bond_slave_widget.cwm_definition,
        bond_options_widget.widget_id  => bond_options_widget.cwm_definition,
        boot_protocol_widget.widget_id => boot_protocol_widget.cwm_definition,
        "REMOTEIP"                     => {
          "widget"            => :textentry,
          # Text entry label
          "label"             => _("R&emote IP Address"),
          "help"              => Ops.get_string(@help, "remoteip", ""),
          "validate_type"     => :function_no_popup,
          "validate_function" => fun_ref(
            method(:ValidateAddrIP),
            "boolean (string, map)"
          ),
          # validation error popup
          "validate_help"     => Ops.add(
            _("The remote IP address is invalid.") + "\n",
            IP.Valid4
          )
        },
        # leftovers
        "S390"                         => {
          "widget" => :push_button,
          # push button label
          "label"  => _("&S/390"),
          "opt"    => [],
          "help"   => "",
          "init"   => fun_ref(CWM.method(:InitNull), "void (string)"),
          "store"  => fun_ref(CWM.method(:StoreNull), "void (string, map)"),
          "handle" => fun_ref(method(:HandleButton), "symbol (string, map)")
        }
      }

      Ops.set(
        res,
        "HWDIALOG",
        Ops.get(widget_descr_hardware, "HWDIALOG", {})
      )

      res
    end

    # `RadioButtonGroup uses CurrentButton instead of Value, grrr
    # @param [String] key widget id
    # @return what property to ask for to get the widget value
    def ValueProp(key)
      if UI.QueryWidget(Id(key), :WidgetClass) == "YRadioButtonGroup"
        return :CurrentButton
      end
      :Value
    end

    # Debug messages configurable at runtime
    # @param class_ [String] debug class
    # @param msg [String] message to log
    def my2debug(class_, msg)
      if SCR.Read(path(".target.size"), Ops.add("/tmp/my2debug/", class_)) != -1
        Builtins.y2internal(Ops.add(Ops.add(class_, ": "), msg))
      end

      nil
    end

    # Default function to init the value of a widget.
    # Used for push buttons.
    # @param [String] key id of the widget
    def InitAddrWidget(key)
      value = Ops.get(@settings, key)
      my2debug("AW", Builtins.sformat("init k: %1, v: %2", key, value))
      UI.ChangeWidget(Id(key), ValueProp(key), value)

      nil
    end

    # Default function to store the value of a widget.
    # @param [String] key	id of the widget
    # @param [Hash] event	the event being handled
    def StoreAddrWidget(key, event)
      event = deep_copy(event)
      value = UI.QueryWidget(Id(key), ValueProp(key))
      my2debug(
        "AW",
        Builtins.sformat("store k: %1, v: %2, e: %3", key, value, event)
      )
      Ops.set(@settings, key, value)

      nil
    end

    # Default function to init the value of slave ETHERDEVICE box.
    # @param _key [String] id of the widget
    def InitVLANSlave(_key)
      items = []
      # unconfigured devices
      Builtins.foreach(
        Convert.convert(
          LanItems.Items,
          from: "map <integer, any>",
          to:   "map <integer, map>"
        )
      ) do |_i, a|
        if Builtins.size(Ops.get_string(a, "ifcfg", "")) == 0
          dev_name = Ops.get_string(a, ["hwinfo", "dev_name"], "")
          items = Builtins.add(
            items,
            Item(
              Id(dev_name),
              dev_name,
              dev_name == Ops.get_string(@settings, "ETHERDEVICE", "") ? true : false
            )
          )
        end
      end
      # configured devices
      configurations = NetworkInterfaces.FilterDevices("netcard")
      Builtins.foreach(
        Builtins.splitstring(
          Ops.get(NetworkInterfaces.CardRegex, "netcard", ""),
          "|"
        )
      ) do |devtype|
        Builtins.foreach(
          Convert.convert(
            Map.Keys(Ops.get_map(configurations, devtype, {})),
            from: "list",
            to:   "list <string>"
          )
        ) do |devname|
          if Builtins.contains(["vlan"], NetworkInterfaces.GetType(devname))
            next
          end
          items = Builtins.add(
            items,
            Item(
              Id(devname),
              Builtins.sformat(
                "%1 - %2",
                devname,
                Ops.get_string(configurations, [devtype, devname, "NAME"], "")
              ),
              Ops.get_string(@settings, "ETHERDEVICE", "") == devname
            )
          )
        end
      end
      UI.ChangeWidget(Id(:vlan_eth), :Items, items)
      UI.ChangeWidget(
        Id(:vlan_id),
        :Value,
        Ops.get_integer(@settings, "VLAN_ID", 0)
      )

      nil
    end

    def HandleVLANSlave(_key, _event)
      # formerly tried to edit ifcfg name. bad idea, surrounding code not ready
      nil
    end

    # Default function to store the value of ETHERDEVICE devices box.
    # @param _key [String] id of the widget
    def StoreVLANSlave(_key, _event)
      Ops.set(
        @settings,
        "ETHERDEVICE",
        Convert.to_string(UI.QueryWidget(Id(:vlan_eth), :Value))
      )
      Ops.set(@settings, "VLAN_ID", UI.QueryWidget(Id(:vlan_id), :Value))

      nil
    end

    def initIfcfg(key)
      UI.ChangeWidget(Id(key), :Value, @settings["IFCFGTYPE"])
      UI.ChangeWidget(Id(key), :Enabled, false)

      nil
    end

    def initIfcfgId(key)
      initHardware
      UI.ChangeWidget(
        Id(key),
        :Value,
        @settings["IFCFGID"]
      )

      nil
    end

    # Remap the buttons to their Wizard Sequencer values
    # @param _key [String] the widget receiving the event
    # @param event [Hash] the event being handled
    # @return nil so that the dialog loops on
    def HandleButton(_key, event)
      event = deep_copy(event)
      ret = Ops.get(event, "ID")
      symbols = { "S390" => :s390 }
      Ops.get(symbols, ret)
    end

    # Validator for IP adresses
    # used for IPADDR and REMOTEIP
    # @param [String] key	the widget being validated
    # @param [Hash] event	the event being handled
    # @return whether valid
    def ValidateAddrIP(key, event)
      event = deep_copy(event)
      if UI.QueryWidget(:bootproto, :CurrentButton) == :static
        return ValidateIP(key, event)
      end
      true
    end

    # @param [Array<String>] types network card types
    # @return their descriptions for CWM
    def BuildTypesListCWM(types)
      types = deep_copy(types)
      Builtins.maplist(types) do |t|
        [t, NetworkInterfaces.GetDevTypeDescription(t, false)]
      end
    end

    def general_tab
      type = LanItems.GetCurrentType

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
                Frame(
                  _("Device Activation"),
                  HBox(startmode_widget.widget_id, ifplugd_priority_widget.widget_id, HStretch())
                ),
                VSpacing(0.4),
                Frame(_("Firewall Zone"), HBox("FWZONE", HStretch())),
                VSpacing(0.4),
                type == "ib" ? HBox("IPOIB_MODE") : Empty(),
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
        VBox("IPADDR", "REMOTEIP")
      )

      address_static_contents = Frame(
        "", # labelless frame
        VBox(
          "IPADDR",
          "NETMASK",
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
        HSpacing(0.5),
        # The combo is a hack to allow changing misdetected
        # interface types. It will work in some cases, like
        # overriding eth to wlan but not in others where we would
        # need to change the contents of the dialog. #30890.
        type != "vlan" ? "IFCFGTYPE" : Empty(),
        HSpacing(1.5),
        MinWidth(30, "IFCFGID"),
        HSpacing(0.5),
        type == "vlan" ? VBox("ETHERDEVICE") : Empty()
      )

      address_contents = if ["tun", "tap"].include?(type)
        VBox(Left(label), tunnel_widget.widget_id)
      else
        VBox(
          Left(label),
          just_address_contents,
          "AD_ADDRESSES"
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
        "contents" => VBox("HWDIALOG")
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
    def AddressDialog(builder: nil)
      @builder = builder
      initialize_address_settings(builder)

      wd = Convert.convert(
        Builtins.union(@widget_descr, widget_descr_local),
        from: "map",
        to:   "map <string, map <string, any>>"
      )

      wd[startmode_widget.widget_id] = startmode_widget.cwm_definition
      wd[ifplugd_priority_widget.widget_id] = ifplugd_priority_widget.cwm_definition

      Ops.set(wd, ["IFCFGTYPE", "items"], BuildTypesListCWM(NetworkInterfaces.GetDeviceTypes))
      Ops.set(
        wd,
        ["IFCFGID", "items"],
        [
          [
            Ops.get_string(@settings, "IFCFGID", ""),
            Ops.get_string(@settings, "IFCFGID", "")
          ]
        ]
      )

      wd["IPOIB_MODE"] = ipoib_mode_widget if builder.type == "ib"

      @settings["IFCFG"] = builder.name if LanItems.operation != :add

      # Firewall config
      firewall_zone = Y2Network::Widgets::FirewallZone.new(builder.name)
      wd["FWZONE"] = firewall_zone.cwm_definition
      firewall_zone.value = @settings["FWZONE"] if firewalld.installed?

      functions = {
        "init"  => fun_ref(method(:InitAddrWidget), "void (string)"),
        "store" => fun_ref(method(:StoreAddrWidget), "void (string, map)"),
        :abort  => fun_ref(LanItems.method(:Rollback), "boolean ()")
      }

      if ["tun", "tap"].include?(builder.type)
        functions = {
          abort: fun_ref(LanItems.method(:Rollback), "boolean ()")
        }
      end

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
        bootproto = @settings.fetch("BOOTPROTO", "")
        ipaddr = @settings.fetch("IPADDR", "")

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
      elsif Builtins.contains(["tun", "tap"], builder.type)
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
