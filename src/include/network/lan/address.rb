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
# File:	include/network/lan/address.ycp
# Package:	Network configuration
# Summary:	Network card adresss configuration dialogs
# Authors:	Michal Svec <msvec@suse.cz>
#
module Yast
  module NetworkLanAddressInclude
    def initialize_network_lan_address(include_target)
      Yast.import "UI"

      textdomain "network"

      Yast.import "Arch"
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
      Yast.import "Routing"
      Yast.import "String"
      Yast.import "SuSEFirewall4Network"
      Yast.import "Wizard"
      Yast.import "NetworkService"
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

      @fwzone_initial = ""

      @hostname_initial = ""

      @force_static_ip = ProductFeatures.GetBooleanFeature(
        "network",
        "force_static_ip"
      )

      @widget_descr_local = {
        "AD_ADDRESSES" => {
          "widget"        => :custom,
          "custom_widget" =>
            # Frame label
            Frame(
              Id(:f_additional),
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
                      _("Alias Name"),
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
        "IFNAME"       => {
          "widget" => :textentry,
          "label"  => _("&Name of Interface"),
          "opt"    => [:hstretch],
          "help"   => _("<p>TODO kind of vague!</p>")
        },
        "FWZONE"       => {
          "widget" => :combobox,
          # Combo Box label
          "label"  => _("Assign Interface to Firewall &Zone"),
          "opt"    => [:hstretch],
          "help"   => Ops.get_string(@help, "fwzone", ""),
          "init"   => fun_ref(method(:InitFwZone), "void (string)")
        },
        "MANDATORY"    => {
          "widget" => :checkbox,
          # check box label
          "label"  => _("&Mandatory Interface"),
          "opt"    => [],
          "help"   => Ops.get_string(@help, "mandatory", "")
        },
        "MTU"          => {
          "widget" => :combobox,
          # textentry label, Maximum Transfer Unit
          "label"  => _("Set &MTU"),
          "opt"    => [:hstretch, :editable],
          "items"  => [
            ["1500", "1500 (Ethernet, DSL broadband)"],
            ["1492", "1492 (PPPoE broadband)"],
            ["576", "576 (dial-up)"]
          ],
          "help"   => Ops.get_string(@help, "mtu", "")
        },
        "IFCFGTYPE"    => {
          "widget"            => :combobox,
          # ComboBox label
          "label"             => _("&Device Type"),
          "opt"               => [:hstretch, :notify],
          "help"              => "",
          # "items" will be filled in the dialog itself
          "init"              => fun_ref(
            method(:initIfcfg),
            "void (string)"
          ),
          #	"handle": HandleIfcfg,
          "validate_type"     => :function,
          "validate_function" => fun_ref(
            method(:ValidateIfcfgType),
            "boolean (string, map)"
          )
        },
        "IFCFGID" =>
          #	"valid_chars": NetworkInterfaces::ValidCharsIfcfg (),
          #	"handle": HandleIfcfg,
          {
            "widget" => :textentry,
            # ComboBox label
            "label"  => _("&Configuration Name"),
            "opt"    => [:hstretch, :disabled],
            "help"   => "",
            "init"   => fun_ref(method(:initIfcfgId), "void (string)")
          },
        "TUNNEL"       => {
          "widget"        => :custom,
          "custom_widget" => VBox(
            Left(CheckBox(Id(:persistent), _("Persistent Tunnel"))),
            HBox(
              InputField(Id(:owner), _("Tunnel owner")),
              InputField(Id(:group), _("Tunnel group"))
            )
          ),
          "help"          => Ops.get_string(@help, "tunnel", ""),
          "init"          => fun_ref(method(:initTunnel), "void (string)"),
          "store"         => fun_ref(method(:storeTunnel), "void (string, map)")
        },
        "BRIDGE_PORTS" => {
          "widget"            => :multi_selection_box,
          "label"             => _("Bridged Devices"),
          "items"             => [],
          "init"              => fun_ref(method(:InitBridge), "void (string)"),
          "store"             => fun_ref(
            method(:StoreBridge),
            "void (string, map)"
          ),
          "validate_type"     => :function,
          "validate_function" => fun_ref(
            method(:ValidateBridge),
            "boolean (string, map)"
          ),
          "help"              => Ops.get_string(@help, "bridge_ports", "")
        },
        "ETHERDEVICE"  => {
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
        "BONDSLAVE"    => {
          "widget"        => :custom,
          "custom_widget" => Frame(
            _("Bond Slaves and Order"),
            VBox(
              MultiSelectionBox(Id(:msbox_items), Opt(:notify), "", []),
              HBox(
                PushButton(Id(:up), Opt(:disabled), _("Up")),
                PushButton(Id(:down), Opt(:disabled), _("Down"))
              )
            )
          ),
          "label"         => _("Bond &Slaves"),
          #        "opt": [`shrinkable],
          "init"          => fun_ref(
            method(:InitSlave),
            "void (string)"
          ),
          "handle"        => fun_ref(
            method(:HandleSlave),
            "symbol (string, map)"
          ),
          "store"         => fun_ref(method(:StoreSlave), "void (string, map)"),
          "help"          => Ops.get_string(@help, "bondslave", "")
        },
        "BONDOPTION"   => {
          "widget" => :combobox,
          # ComboBox label
          "label"  => _("&Bond Driver Options"),
          "opt"    => [:hstretch, :editable],
          "help"   => _(
            "<p>Select the bond driver options and edit them if necessary. </p>"
          ),
          "items"  => [
            ["mode=balance-rr miimon=100"],
            ["mode=active-backup miimon=100"],
            ["mode=balance-xor miimon=100"],
            ["mode=broadcast miimon=100"],
            ["mode=802.3ad miimon=100"],
            ["mode=balance-tlb miimon=100"],
            ["mode=balance-alb miimon=100"]
          ]
        },
        "BOOTPROTO"    => {
          "widget"            => :custom,
          "custom_widget"     => RadioButtonGroup(
            Id(:bootproto),
            VBox(
              ReplacePoint(
                Id(:rp),
                Left(
                  HBox(
                    RadioButton(
                      Id(:none),
                      Opt(:notify),
                      _("No Link and IP Setup (Bonding Slaves)")
                    ),
                    HSpacing(1),
                    CheckBox(Id(:ibft), Opt(:notify), _("Use iBFT values"))
                  )
                )
              ),
              Left(
                HBox(
                  RadioButton(Id(:dynamic), Opt(:notify), _("Dynamic Address")),
                  HSpacing(2),
                  ComboBox(
                    Id(:dyn),
                    "",
                    [
                      Item(Id(:dhcp), "DHCP"),
                      Item(Id(:dhcp_auto), "DHCP+Zeroconf"),
                      Item(Id(:auto), "Zeroconf")
                    ]
                  ),
                  HSpacing(2),
                  ComboBox(
                    Id(:dhcp_mode),
                    "",
                    [
                      Item(Id(:dhcp_both), _("DHCP both version 4 and 6")),
                      Item(Id(:dhcp_v4), _("DHCP version 4 only")),
                      Item(Id(:dhcp_v6), _("DHCP version 6 only"))
                    ]
                  )
                )
              ),
              VBox(
                # TODO : Stat ... Assigned
                Left(
                  RadioButton(
                    Id(:static),
                    Opt(:notify),
                    _("Statically assigned IP Address")
                  )
                ),
                HBox(
                  InputField(Id(:ipaddr), Opt(:hstretch), _("&IP Address")),
                  HSpacing(1),
                  InputField(Id(:netmask), Opt(:hstretch), _("&Subnet Mask")),
                  HSpacing(1),
                  InputField(Id(:hostname), Opt(:hstretch), _("&Hostname")),
                  HStretch()
                )
              )
            )
          ),
          "help"              => Ops.add(
            @force_static_ip ?
              Ops.get_string(@help, "force_static_ip", "") :
              Ops.get_string(@help, "bootproto", ""),
            Ops.get_string(@help, "netmask", "")
          ),
          "init"              => fun_ref(
            method(:initBootProto),
            "void (string)"
          ),
          "handle"            => fun_ref(
            method(:handleBootProto),
            "symbol (string, map)"
          ),
          "store"             => fun_ref(
            method(:storeBootProto),
            "void (string, map)"
          ),
          "validate_type"     => :function,
          "validate_function" => fun_ref(
            method(:ValidateBootproto),
            "boolean (string, map)"
          )
        },
        "REMOTEIP"     => {
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
        "ADVANCED_MB"  => {
          "widget" => :menu_button,
          # menu button label
          "label"  => _("&Advanced..."),
          "opt"    => [:hstretch],
          "help"   => "",
          # "items" will be filled in the dialog itself
          "init"   => fun_ref(
            CWM.method(:InitNull),
            "void (string)"
          ),
          "store"  => fun_ref(CWM.method(:StoreNull), "void (string, map)"),
          "handle" => fun_ref(method(:HandleButton), "symbol (string, map)")
        },
        # leftovers
        "S390"         => {
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
        @widget_descr_local,
        "HWDIALOG",
        Ops.get(@widget_descr_hardware, "HWDIALOG", {})
      )
    end

    # obsoleted by GetDefaultsForHW
    # @return `next
    def ChangeDefaults
      :next
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
    # @param [String] class debug class
    # @param [String] msg message to log
    def my2debug(_class, msg)
      if SCR.Read(path(".target.size"), Ops.add("/tmp/my2debug/", _class)) != -1
        Builtins.y2internal(Ops.add(Ops.add(_class, ": "), msg))
      end

      nil
    end

    # Default function to init the value of a widget.
    # Used for push buttons.
    # @param [String] key id of the widget
    def InitAddrWidget(key)
      value = Ops.get(@settings, key)
      my2debug("AW", Builtins.sformat("init k: %1, v: %2", key, value))
      # because IFPLUGD_PRIORITY is integer, not string
      if key != "IFPLUGD_PRIORITY"
        UI.ChangeWidget(Id(key), ValueProp(key), value)
      end

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


    # Default function to store the value of devices attached to bridge (BRIDGE_PORTS).
    # @param [String] key	id of the widget
    # @param [String] key id of the widget
    def StoreBridge(key, event)
      event = deep_copy(event)
      Ops.set(
        @settings,
        "BRIDGE_PORTS",
        String.CutBlanks(
          Builtins.mergestring(
            Convert.convert(
              UI.QueryWidget(Id("BRIDGE_PORTS"), :SelectedItems),
              :from => "any",
              :to   => "list <string>"
            ),
            " "
          )
        )
      )
      Builtins.y2milestone(
        "store bridge %1 : %2",
        key,
        Ops.get_string(@settings, "BRIDGE_PORTS", "")
      )

      nil
    end


    # Default function to init the value of slave ETHERDEVICE box.
    # @param [String] key	id of the widget
    def InitVLANSlave(key)
      items = []
      # unconfigured devices
      Builtins.foreach(
        Convert.convert(
          LanItems.Items,
          :from => "map <integer, any>",
          :to   => "map <integer, map>"
        )
      ) do |i, a|
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
            :from => "list",
            :to   => "list <string>"
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


    def HandleVLANSlave(key, event)
      event = deep_copy(event)
      # formerly tried to edit ifcfg name. bad idea, surrounding code not ready
      nil
    end

    # Default function to store the value of ETHERDEVICE devices box.
    # @param [String] key	id of the widget
    # @param [String] key id of the widget
    def StoreVLANSlave(key, event)
      event = deep_copy(event)
      Ops.set(
        @settings,
        "ETHERDEVICE",
        Convert.to_string(UI.QueryWidget(Id(:vlan_eth), :Value))
      )
      Ops.set(@settings, "VLAN_ID", UI.QueryWidget(Id(:vlan_id), :Value))

      nil
    end

    def getISlaveIndex(slave)
      items = Convert.convert(
        UI.QueryWidget(:msbox_items, :Items),
        :from => "any",
        :to   => "list <term>"
      )
      index = -1
      pos = 0
      Builtins.foreach(items) do |it|
        if Ops.get_string(it, [0, 0], "") == slave
          index = pos
          raise Break
        end
        pos = Ops.add(pos, 1)
      end
      index
    end

    def enableSlaveButtons
      items = Convert.convert(
        UI.QueryWidget(:msbox_items, :Items),
        :from => "any",
        :to   => "list <term>"
      )
      current = Builtins.tostring(UI.QueryWidget(:msbox_items, :CurrentItem))
      index = getISlaveIndex(current)
      UI.ChangeWidget(:up, :Enabled, Ops.greater_than(index, 0))
      UI.ChangeWidget(
        :down,
        :Enabled,
        Ops.less_than(index, Ops.subtract(Builtins.size(items), 1))
      )

      nil
    end

    # Default function to init the value of slave devices box for bonding.
    # @param [String] key	id of the widget
    def InitSlave(key)
      Ops.set(@settings, "SLAVES", LanItems.bond_slaves)
      UI.ChangeWidget(
        :msbox_items,
        :SelectedItems,
        Ops.get_list(@settings, "SLAVES", [])
      )

      Ops.set(@settings, "BONDOPTION", LanItems.bond_option)

      items = CreateSlaveItems(
        LanItems.GetBondableInterfaces(LanItems.GetCurrentName),
        LanItems.bond_slaves
      )

      # reorder the items
      l2 = []
      l1 = []
      Builtins.foreach(
        Convert.convert(items, :from => "list", :to => "list <term>")
      ) do |t|
        if Builtins.contains(
            Ops.get_list(@settings, "SLAVES", []),
            Ops.get_string(t, [0, 0], "")
          )
          l1 = Builtins.add(l1, t)
        else
          l2 = Builtins.add(l2, t)
        end
      end

      items = []
      Builtins.foreach(Ops.get_list(@settings, "SLAVES", [])) do |s|
        Builtins.foreach(
          Convert.convert(l1, :from => "list", :to => "list <term>")
        ) do |t|
          items = Builtins.add(items, t) if Ops.get_string(t, [0, 0], "") == s
        end
      end

      items = Builtins.union(items, l2)
      UI.ChangeWidget(:msbox_items, :Items, items)
      enableSlaveButtons

      nil
    end

    def HandleSlave(key, event)
      event = deep_copy(event)
      if Ops.get_string(event, "EventReason", "") == "SelectionChanged"
        enableSlaveButtons
      elsif Ops.get_string(event, "EventReason", "") == "Activated" &&
          Ops.get(event, "WidgetClass") == :PushButton
        items = Convert.convert(
          UI.QueryWidget(:msbox_items, :Items),
          :from => "any",
          :to   => "list <term>"
        )
        current = Builtins.tostring(UI.QueryWidget(:msbox_items, :CurrentItem))
        index = getISlaveIndex(current)
        new_items = []
        pos = 0
        case Ops.get_symbol(event, "ID", :nil)
          when :up
            while Ops.greater_than(index, Ops.add(pos, 1))
              new_items = Builtins.add(new_items, Ops.get(items, pos))
              pos = Ops.add(pos, 1)
            end
            new_items = Builtins.add(new_items, Ops.get(items, index))
            new_items = Builtins.add(
              new_items,
              Ops.get(items, Ops.subtract(index, 1))
            )
            new_items = Convert.convert(
              Builtins.union(new_items, Builtins.sublist(items, index)),
              :from => "list",
              :to   => "list <term>"
            )
          when :down
            while Ops.greater_than(index, pos)
              new_items = Builtins.add(new_items, Ops.get(items, pos))
              pos = Ops.add(pos, 1)
            end
            new_items = Builtins.add(
              new_items,
              Ops.get(items, Ops.add(index, 1))
            )
            new_items = Builtins.add(new_items, Ops.get(items, index))
            new_items = Convert.convert(
              Builtins.union(
                new_items,
                Builtins.sublist(items, Ops.add(index, 1))
              ),
              :from => "list",
              :to   => "list <term>"
            )
          else
            Builtins.y2warning("unknown action")
            return nil
        end
        items = deep_copy(new_items)
        UI.ChangeWidget(:msbox_items, :Items, items)
        enableSlaveButtons
      else
        Builtins.y2debug("event:%1", event)
      end

      nil
    end

    # Default function to store the value of slave devices box.
    # @param [String] key	id of the widget
    # @param [String] key id of the widget
    def StoreSlave(key, event)
      event = deep_copy(event)
      configured_slaves = Ops.get_list(@settings, "SLAVES", [])

      Ops.set(
        @settings,
        "SLAVES",
        Convert.convert(
          UI.QueryWidget(:msbox_items, :SelectedItems),
          :from => "any",
          :to   => "list <string>"
        )
      )
      Ops.set(@settings, "BONDOPTION", UI.QueryWidget(Id("BONDOPTION"), :Value))

      LanItems.bond_slaves = Ops.get_list(@settings, "SLAVES", [])
      LanItems.bond_option = Ops.get_string(@settings, "BONDOPTION", "")

      # create list of "unconfigured" slaves
      new_slaves = Builtins.filter(Ops.get_list(@settings, "SLAVES", [])) do |slave|
        !Builtins.contains(configured_slaves, slave)
      end

      Lan.bond_autoconf_slaves = Convert.convert(
        Builtins.toset(Builtins.merge(Lan.bond_autoconf_slaves, new_slaves)),
        :from => "list",
        :to   => "list <string>"
      )

      nil
    end

    def initTunnel(key)
      Builtins.y2internal("initTunnel %1", @settings)
      UI.ChangeWidget(
        :persistent,
        :Value,
        Ops.get_string(@settings, "TUNNEL_SET_PERSISTENT", "") == "yes"
      )
      UI.ChangeWidget(
        :owner,
        :Value,
        Ops.get_string(@settings, "TUNNEL_SET_OWNER", "")
      )
      UI.ChangeWidget(
        :group,
        :Value,
        Ops.get_string(@settings, "TUNNEL_SET_GROUP", "")
      )

      nil
    end

    def storeTunnel(key, event)
      event = deep_copy(event)
      Ops.set(
        @settings,
        "TUNNEL_SET_PERSISTENT",
        Convert.to_boolean(UI.QueryWidget(:persistent, :Value)) ? "yes" : "no"
      )
      Ops.set(
        @settings,
        "TUNNEL_SET_OWNER",
        Convert.to_string(UI.QueryWidget(:owner, :Value))
      )
      Ops.set(
        @settings,
        "TUNNEL_SET_GROUP",
        Convert.to_string(UI.QueryWidget(:group, :Value))
      )

      nil
    end

    def enableDisableBootProto(current)
      UI.ChangeWidget(:dyn, :Enabled, current == :dynamic)
      UI.ChangeWidget(:dhcp_mode, :Enabled, current == :dynamic)
      UI.ChangeWidget(:ipaddr, :Enabled, current == :static)
      UI.ChangeWidget(:netmask, :Enabled, current == :static)
      UI.ChangeWidget(:hostname, :Enabled, current == :static)
      UI.ChangeWidget(:ibft, :Enabled, current == :none)

      nil
    end

    # Initialize a RadioButtonGroup
    # Group called FOO has buttons FOO_bar FOO_qux and values bar qux
    # @param [String] key id of the widget
    def initBootProto(key)
      #  if (LanItems::type=="br") UI::ReplaceWidget(`rp, `Empty());
      # 	else
      if LanItems.type != "eth"
        UI.ReplaceWidget(
          :rp,
          Left(
            RadioButton(
              Id(:none),
              Opt(:notify),
              _("No Link and IP Setup (Bonding Slaves)")
            )
          )
        )
      end

      case Ops.get_string(@settings, "BOOTPROTO", "")
        when "static"
          UI.ChangeWidget(Id(:bootproto), :CurrentButton, :static)
          UI.ChangeWidget(
            Id(:ipaddr),
            :Value,
            Ops.get_string(@settings, "IPADDR", "")
          )
          if Ops.greater_than(
              Builtins.size(Ops.get_string(@settings, "PREFIXLEN", "")),
              0
            )
            UI.ChangeWidget(
              Id(:netmask),
              :Value,
              Builtins.sformat(
                "/%1",
                Ops.get_string(@settings, "PREFIXLEN", "")
              )
            )
          else
            UI.ChangeWidget(
              Id(:netmask),
              :Value,
              Ops.get_string(@settings, "NETMASK", "")
            )
          end
          UI.ChangeWidget(
            Id(:hostname),
            :Value,
            Ops.get_string(@settings, "HOSTNAME", "")
          )
        when "dhcp"
          UI.ChangeWidget(Id(:bootproto), :CurrentButton, :dynamic)
          UI.ChangeWidget(Id(:dhcp_mode), :Value, :dhcp_both)
        when "dhcp4"
          UI.ChangeWidget(Id(:bootproto), :CurrentButton, :dynamic)
          UI.ChangeWidget(Id(:dhcp_mode), :Value, :dhcp_v4)
        when "dhcp6"
          UI.ChangeWidget(Id(:bootproto), :CurrentButton, :dynamic)
          UI.ChangeWidget(Id(:dhcp_mode), :Value, :dhcp_v6)
        when "dhcp+autoip"
          UI.ChangeWidget(Id(:bootproto), :CurrentButton, :dynamic)
          UI.ChangeWidget(Id(:dyn), :Value, :dhcp_auto)
        when "autoip"
          UI.ChangeWidget(Id(:bootproto), :CurrentButton, :dynamic)
          UI.ChangeWidget(Id(:dyn), :Value, :auto)
        when "none"
          UI.ChangeWidget(Id(:bootproto), :CurrentButton, :none)
        when "ibft"
          UI.ChangeWidget(Id(:bootproto), :CurrentButton, :none)
          UI.ChangeWidget(Id(:ibft), :Value, true)
      end

      enableDisableBootProto(
        Convert.to_symbol(UI.QueryWidget(Id(:bootproto), :CurrentButton))
      )

      nil
    end


    def handleBootProto(key, event)
      event = deep_copy(event)
      if Ops.get_string(event, "EventReason", "") == "ValueChanged"
        current = Convert.to_symbol(
          UI.QueryWidget(Id(:bootproto), :CurrentButton)
        )
        enableDisableBootProto(current)

        if current == :static
          one_ip = Convert.to_string(UI.QueryWidget(Id(:ipaddr), :Value))
          if Builtins.size(one_ip) == 0
            Builtins.y2milestone("Presetting global hostname")
            UI.ChangeWidget(
              Id(:hostname),
              :Value,
              Hostname.MergeFQ(DNS.hostname, DNS.domain)
            )
          end
        end
      end
      nil
    end


    # Store a RadioButtonGroup
    # Group called FOO has buttons FOO_bar FOO_qux and values bar qux
    # @param [String] key	id of the widget
    # @param [Hash] event	the event being handled
    def storeBootProto(key, event)
      event = deep_copy(event)
      case Convert.to_symbol(UI.QueryWidget(Id(:bootproto), :CurrentButton))
        when :none
          @bootproto = "none"
          if UI.WidgetExists(Id(:ibft))
            @bootproto = Convert.to_boolean(UI.QueryWidget(Id(:ibft), :Value)) ? "ibft" : "none"
          end
          Ops.set(@settings, "BOOTPROTO", @bootproto)
          Ops.set(@settings, "IPADDR", "")
          Ops.set(@settings, "NETMASK", "")
          Ops.set(@settings, "PREFIXLEN", "")
        when :static
          Ops.set(@settings, "BOOTPROTO", "static")
          Ops.set(@settings, "NETMASK", "")
          Ops.set(@settings, "PREFIXLEN", "")
          Ops.set(
            @settings,
            "IPADDR",
            Convert.to_string(UI.QueryWidget(:ipaddr, :Value))
          )
          @mask = Convert.to_string(UI.QueryWidget(:netmask, :Value))
          if Builtins.substring(@mask, 0, 1) == "/"
            Ops.set(@settings, "PREFIXLEN", Builtins.substring(@mask, 1))
          else
            if Netmask.Check6(@mask)
              Ops.set(@settings, "PREFIXLEN", @mask)
            else
              Ops.set(@settings, "NETMASK", @mask)
            end
          end
          Ops.set(
            @settings,
            "HOSTNAME",
            Convert.to_string(UI.QueryWidget(:hostname, :Value))
          )
        else
          case Convert.to_symbol(UI.QueryWidget(:dyn, :Value))
            when :dhcp
              case Convert.to_symbol(UI.QueryWidget(:dhcp_mode, :Value))
                when :dhcp_both
                  Ops.set(@settings, "BOOTPROTO", "dhcp")
                when :dhcp_v4
                  Ops.set(@settings, "BOOTPROTO", "dhcp4")
                when :dhcp_v6
                  Ops.set(@settings, "BOOTPROTO", "dhcp6")
              end
            when :dhcp_auto
              Ops.set(@settings, "BOOTPROTO", "dhcp+autoip")
            when :auto
              Ops.set(@settings, "BOOTPROTO", "autoip")
          end
          Ops.set(@settings, "IPADDR", "")
          Ops.set(@settings, "NETMASK", "")
      end

      nil
    end


    def initIfcfg(key)
      UI.ChangeWidget(Id(key), :Value, LanItems.type)
      UI.ChangeWidget(Id(key), :Enabled, false)

      nil
    end

    def initIfcfgId(key)
      initHardware
      UI.ChangeWidget(
        Id(key),
        :Value,
        Ops.get_string(LanItems.Items, [LanItems.current, "ifcfg"], "")
      )

      nil
    end

    # Remap the buttons to their Wizard Sequencer values
    # @param [String] key	the widget receiving the event
    # @param [Hash] event	the event being handled
    # @return nil so that the dialog loops on
    def HandleButton(key, event)
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

    # Validator for network masks adresses
    # @param [String] key	the widget being validated
    # @param [Hash] event	the event being handled
    # @return whether valid
    def ValidateNetmask(key, event)
      event = deep_copy(event)
      # TODO general CWM improvement idea: validate and save only nondisabled
      # widgets
      if UI.QueryWidget(:bootproto, :CurrentButton) == :static
        ipa = Convert.to_string(UI.QueryWidget(Id(key), :Value))
        return Netmask.Check(ipa)
      end
      true
    end

    # Validator for ifcfg names
    # @param [String] key	the widget being validated
    # @param [Hash] event	the event being handled
    # @return whether valid
    def ValidateIfcfgType(key, event)
      event = deep_copy(event)
      if LanItems.operation == :add
        ifcfgtype = Convert.to_string(UI.QueryWidget(Id(key), :Value))

        # validate device type, misdetection
        if ifcfgtype != LanItems.type
          UI.SetFocus(Id(key))
          if !Popup.ContinueCancel(
              _(
                "You have changed the interface type from the one\n" +
                  "that has been detected. This only makes sense\n" +
                  "if you know that the detection is wrong."
              )
            )
            return false
          end
        end

        ifcfgid = Convert.to_string(UI.QueryWidget(Id("IFCFGID"), :Value))
        ifcfgname = Builtins.sformat("%1%2", ifcfgtype, ifcfgid)

        # Check should be improved to find differently named but
        # equivalent configs (eg. by-mac and by-bus, depends on the
        # current hardware)
        if NetworkInterfaces.Check(ifcfgname)
          UI.SetFocus(Id(key))
          # Popup text
          Popup.Error(
            Builtins.sformat(_("Configuration %1 already present."), ifcfgname)
          )
          return false
        end
      end
      true
    end

    # If the traffic would be blocked, ask the user
    # if he wants to change it
    # @param [Hash] event	the event being handled
    # @return change it?
    def NeedToAssignFwZone(event)
      event = deep_copy(event)
      ret = Ops.get(event, "ID")
      if ret == :next
        # If firewall is active and interface in no zone, nothing
        # gets through (#62309) so warn and redirect to details
        name = Convert.to_string(UI.QueryWidget(Id("IFCFGID"), :Value))
        if SuSEFirewall4Network.IsOn &&
            SuSEFirewall4Network.GetZoneOfInterface(name) == "" &&
            SuSEFirewall4Network.UnconfiguredIsBlocked
          return Popup.YesNoHeadline(
            Label.WarningMsg,
            _(
              "The firewall is active, but this interface is not\n" +
                "in any zone. All its traffic would be blocked.\n" +
                "Assign it to a zone now?"
            )
          )
        end
      end
      false
    end

    # Validator for network masks adresses
    # @param [String] key	the widget being validated
    # @param [Hash] event	the event being handled
    # @return whether valid
    def ValidateBootproto(key, event)
      event = deep_copy(event)
      if UI.QueryWidget(:bootproto, :CurrentButton) == :static
        ipa = Convert.to_string(UI.QueryWidget(:ipaddr, :Value))
        if ipa != "" && !IP.Check(ipa)
          Popup.Error(_("No valid IP address."))
          UI.SetFocus(:ipaddr)
          return false
        end

        mask = Convert.to_string(UI.QueryWidget(:netmask, :Value))
        if ipa != "" && mask != "" && !validPrefixOrNetmask(ipa, mask)
          Popup.Error(_("No valid netmask or prefix length."))
          UI.SetFocus(:netmask)
          return false
        end

        hname = Convert.to_string(UI.QueryWidget(:hostname, :Value))
        if Ops.greater_than(Builtins.size(hname), 0)
          if !Hostname.CheckFQ(hname)
            Popup.Error(_("Invalid hostname."))
            UI.SetFocus(:hostname)
            return false
          end
        else
          # There'll be no 127.0.0.2 -> remind user to define some hostname
          if !Host.NeedDummyIP &&
              !Popup.YesNo(
                _(
                  "No hostname has been specified. We recommend to associate \n" +
                    "a hostname with a static IP, otherwise the machine name will \n" +
                    "not be resolvable without an active network connection.\n" +
                    "\n" +
                    "Really leave the hostname blank?\n"
                )
              )
            UI.SetFocus(:hostname)
            return false
          end
        end

        # validate duplication
        if NetHwDetection.DuplicateIP(ipa)
          UI.SetFocus(:ipaddr)
          # Popup text
          if !Popup.YesNoHeadline(
              Label.WarningMsg,
              _("Duplicate IP address detected.\nReally continue?\n")
            )
            return false
          end
        end
      end
      if NeedToAssignFwZone(event)
        UI.FakeUserInput({ "ID" => "t_general" })
        return false
      end
      true
    end

    # Initialize value of firewall zone widget
    # (disables it when SuSEFirewall is not installed)
    # @param [String] key id of the widget
    def InitFwZone(key)
      if SuSEFirewall4Network.IsInstalled
        UI.ChangeWidget(
          Id("FWZONE"),
          :Value,
          Ops.get_string(@settings, "FWZONE", "")
        )
      else
        UI.ChangeWidget(Id("FWZONE"), :Enabled, false)
      end

      nil
    end

    # @param [Array<String>] types network card types
    # @return their descriptions for CWM
    def BuildTypesListCWM(types)
      types = deep_copy(types)
      Builtins.maplist(types) do |t|
        [t, NetworkInterfaces.GetDevTypeDescription(t, false)]
      end
    end


    def initIfplugdPriority(key)
      UI.ChangeWidget(
        Id("IFPLUGD_PRIORITY"),
        :Value,
        Builtins.tointeger(Ops.get_string(@settings, "IFPLUGD_PRIORITY", "0"))
      )

      nil
    end

    def handleStartmode(key, event)
      event = deep_copy(event)
      UI.ChangeWidget(
        Id("IFPLUGD_PRIORITY"),
        :Enabled,
        UI.QueryWidget(Id("STARTMODE"), :Value) == "ifplugd"
      )
      nil
    end

    # Dialog for setting up IP address
    # @return dialog result
    def AddressDialog
      fwzone = SuSEFirewall4Network.GetZoneOfInterface(LanItems.GetCurrentName)

      # If firewall is active and interface in no zone, nothing
      # gets through (#62309) so add it to the external zone
      if fwzone == "" && LanItems.operation == :add && SuSEFirewall4Network.IsOn &&
          SuSEFirewall4Network.UnconfiguredIsBlocked
        fwzone = "EXT"
        Builtins.y2milestone("Defaulting to EXT")
      end

      @fwzone_initial = fwzone

      host_list = Ops.get(Host.hosts, LanItems.ipaddr, [])
      if Ops.greater_than(Builtins.size(host_list), 1)
        Builtins.y2milestone(
          "More than one hostname for single IP detected, using the first one only"
        )
      end
      @hostname_initial = String.FirstChunk(Ops.get(host_list, 0, ""), " \t")

      @settings = {
        # general tab:
        "STARTMODE"        => LanItems.startmode(
        ),
        "IFPLUGD_PRIORITY" => LanItems.ifplugd_priority,
        "USERCONTROL"      => LanItems.usercontrol,
        # problems when renaming the interface?
        "FWZONE"           => fwzone,
        "MTU"              => LanItems.mtu,
        # address tab:
        "BOOTPROTO"        => LanItems.bootproto,
        "IPADDR"           => LanItems.ipaddr,
        "NETMASK"          => LanItems.netmask,
        "PREFIXLEN"        => LanItems.prefix,
        "REMOTEIP"         => LanItems.remoteip,
        "HOSTNAME"         => @hostname_initial,
        "IFCFGTYPE"        => LanItems.type,
        "IFCFGID"          => LanItems.device
      }

      drvtype = DriverType(Ops.get_string(@settings, "IFCFGTYPE", ""))

      is_ptp = drvtype == "ctc" || drvtype == "iucv"
      # TODO: dynamic for dummy. or add dummy from outside?
      no_dhcp = is_ptp || Ops.get_string(@settings, "IFCFGTYPE", "") == "dummy" ||
        LanItems.alias != ""

      if LanItems.type == "vlan"
        Ops.set(@settings, "ETHERDEVICE", LanItems.vlan_etherdevice)
        Ops.set(@settings, "VLAN_ID", Builtins.tointeger(LanItems.vlan_id))
      end

      if Builtins.contains(["tun", "tap"], LanItems.type)
        @settings = {
          "BOOTPROTO"             => "static",
          "STARTMODE"             => "auto",
          "TUNNEL"                => LanItems.type,
          "TUNNEL_SET_PERSISTENT" => LanItems.tunnel_set_persistent ? "yes" : "no",
          "TUNNEL_SET_OWNER"      => LanItems.tunnel_set_owner,
          "TUNNEL_SET_GROUP"      => LanItems.tunnel_set_group
        }
      end

      # #65524
      if LanItems.operation == :add && @force_static_ip
        Ops.set(@settings, "BOOTPROTO", "static")
      end

      # FIXME duplicated in hardware.ycp
      device_types = [
        "arc",
        "bnep",
        "dummy",
        "eth",
        "fddi",
        "myri",
        "tr",
        "usb",
        "wlan",
        "bond",
        "vlan",
        "br",
        "tun",
        "tap",
        "ib"
      ]

      if Arch.s390
        device_types = [
          "eth",
          "tr",
          "hsi",
          "ctc",
          "escon",
          "ficon",
          "iucv",
          "qeth",
          "lcs",
          "vlan",
          "br",
          "tun",
          "tap"
        ]
      end

      device_types = Builtins.add(device_types, "xp") if Arch.ia64

      fw_is_installed = SuSEFirewall4Network.IsInstalled

      wd = Convert.convert(
        Builtins.union(@widget_descr, @widget_descr_local),
        :from => "map",
        :to   => "map <string, map <string, any>>"
      )


      Ops.set(
        wd,
        "STARTMODE",
        MakeStartmode(
          ["auto", "ifplugd", "hotplug", "manual", "off", "nfsroot"]
        )
      )
      Ops.set(
        wd,
        ["STARTMODE", "handle"],
        fun_ref(method(:handleStartmode), "symbol (string, map)")
      )
      Ops.set(wd, ["STARTMODE", "opt"], [:notify])

      Ops.set(
        wd,
        "IFPLUGD_PRIORITY",
        {
          "widget"  => :intfield,
          "minimum" => 0,
          "maximum" => 100,
          # Combo box label - when to activate device (e.g. on boot, manually, never,..)
          "label"   => _(
            "Ifplugd priority"
          ),
          "help" =>
            # Device activation main help. The individual parts will be
            # substituted as %1
            _(
              "<p><b><big>IFPLUGD PRIORITY</big></b></p> \n" +
                "<p> All interfaces configured with <b>On Cable Connection</b> and with IFPLUGD_PRIORITY != 0 will be\n" +
                " used mutually exclusive. If more then one of these interfaces is <b>On Cable Connection</b>\n" +
                " then we need a way to decide which interface to take up. Therefore we have to\n" +
                " set the priority of each interface.  </p>\n"
            ),
          "init"    => fun_ref(method(:initIfplugdPriority), "void (string)")
        }
      )

      Ops.set(wd, ["IFCFGTYPE", "items"], BuildTypesListCWM(device_types))
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

      if fw_is_installed
        Ops.set(
          wd,
          ["FWZONE", "items"],
          SuSEFirewall4Network.FirewallZonesComboBoxItems
        )
      else
        Ops.set(
          wd,
          ["FWZONE", "items"],
          [["", _("Firewall is not installed.")]]
        )
      end


      label = HBox(
        HSpacing(0.5),
        # The combo is a hack to allow changing misdetected
        # interface types. It will work in some cases, like
        # overriding eth to wlan but not in others where we would
        # need to change the contents of the dialog. #30890.
        LanItems.type != "vlan" ?
          "IFCFGTYPE" :
          Empty(),
        HSpacing(1.5),
        MinWidth(30, "IFCFGID"),
        HSpacing(0.5),
        LanItems.type == "vlan" ? VBox("ETHERDEVICE") : Empty()
      )
      if LanItems.operation != :add
        if LanItems.alias == ""
          Ops.set(@settings, "IFCFG", LanItems.device)
        else
          Ops.set(@settings, "IFCFG", LanItems.device)
        end
      end

      mb_items = []
      Ops.set(wd, ["ADVANCED_MB", "items"], Builtins.maplist(mb_items) do |btn|
        [btn, Ops.get_string(wd, [btn, "label"], btn)]
      end)

      frame2 = Empty()
      if Ops.greater_than(Builtins.size(mb_items), 0)
        frame2 = MarginBox(
          1,
          0,
          Frame(
            _("Detailed Settings"),
            HBox(
              HStretch(),
              HSquash(
                VBox(
                  "ADVANCED_MB"
                )
              ),
              HStretch()
            )
          )
        )
      end

      frame2 = VSpacing(0) if LanItems.alias != ""

      address_p2p_contents = Frame(
        "", # labelless frame
        VBox("IPADDR", "REMOTEIP")
      )

      address_static_contents = Frame(
        "", # labelless frame
        VBox(
          "IPADDR",
          "NETMASK",
          # TODO new widget, add logic
          #"GATEWAY"
          Empty()
        )
      )

      address_dhcp_contents = VBox("BOOTPROTO")
      just_address_contents = is_ptp ?
        address_p2p_contents :
        no_dhcp ? address_static_contents : address_dhcp_contents

      address_contents = VBox(
        Left(label),
        just_address_contents,
        "AD_ADDRESSES",
        frame2
      )

      if Builtins.contains(["tun", "tap"], LanItems.type)
        address_contents = VBox(Left(label), "TUNNEL", frame2)
      end


      functions = {
        "init"  => fun_ref(method(:InitAddrWidget), "void (string)"),
        "store" => fun_ref(method(:StoreAddrWidget), "void (string, map)"),
        :abort  => fun_ref(LanItems.method(:Rollback), "boolean ()")
      }

      if Builtins.contains(["tun", "tap"], LanItems.type)
        functions = {
          :abort => fun_ref(LanItems.method(:Rollback), "boolean ()")
        }
      end



      wd_content = {
        "tab_order"          => ["t_general", "t_addr", "hardware"],
        "tabs"               => {
          "t_general"    => {
            "header"   => _("&General"),
            "contents" => MarginBox(
              1,
              0,
              VBox(
                MarginBox(
                  1,
                  0,
                  VBox(
                    # TODO:
                    # "MANDATORY",
                    Frame(
                      _("Device Activation"),
                      HBox("STARTMODE", "IFPLUGD_PRIORITY", HStretch())
                    ),
                    VSpacing(0.4),
                    Frame(_("Firewall Zone"), HBox("FWZONE", HStretch())),
                    VSpacing(0.4),
                    Frame(_("Device Control"), HBox("USERCONTROL", HStretch())),
                    VSpacing(0.4),
                    Frame(
                      _("Maximum Transfer Unit (MTU)"),
                      HBox("MTU", HStretch())
                    ),
                    VStretch()
                  )
                )
              )
            ),
            # FIXME we have helps per widget and for the whole
            # tab set but not for one tab
            "help"     => _(
              "<p>Configure the detailed network card settings here.</p>"
            )
          },
          "t_addr"       => {
            # FIXME: here it does not complain about missing
            # shortcuts
            "header"   => _(
              "&Address"
            ),
            "contents" => address_contents,
            # Address tab help
            "help"     => _(
              "<p>Configure your IP address.</p>"
            )
          },
          "hardware"     => {
            "header"   => _("&Hardware"),
            "contents" => VBox("HWDIALOG")
          },
          "bond_slaves"  => {
            "header"   => _("&Bond Slaves"),
            "contents" => VBox("BONDSLAVE", "BONDOPTION")
          },
          "bridge_ports" => {
            "header"   => _("Bridged Devices"),
            "contents" => VBox("BRIDGE_PORTS")
          },
          "t3"           => {
            "header"       => _("&Wireless"),
            "contents"     => Empty(),
            "widget_names" => []
          }
        },
        "initial_tab"        => "t_addr",
        "widget_descr"       => wd,
        "tab_help"           => "",
        "fallback_functions" => functions
      }
      if LanItems.type == "vlan"
        Ops.set(wd_content, "tab_order", ["t_general", "t_addr"])
      end
      if Builtins.contains(["tun", "tap"], LanItems.type)
        Ops.set(wd_content, "tab_order", ["t_addr"])
      end
      if LanItems.type == "br"
        Ops.set(
          wd_content,
          "tab_order",
          ["t_general", "t_addr", "bridge_ports"]
        )
      end
      if LanItems.type == "bond"
        Ops.set(
          wd_content,
          "tab_order",
          Builtins.add(Ops.get_list(wd_content, "tab_order", []), "bond_slaves")
        )
      end

      wd = Convert.convert(
        Builtins.union(wd, { "tab" => CWMTab.CreateWidget(wd_content) }),
        :from => "map",
        :to   => "map <string, map <string, any>>"
      )

      ret = CWM.ShowAndRun(
        {
          "widget_names"       => ["tab"],
          "widget_descr"       => wd,
          "contents"           => HBox("tab"),
          # Address dialog caption
          "caption"            => _(
            "Network Card Setup"
          ),
          "back_button"        => Label.BackButton,
          "abort_button"       => Label.CancelButton,
          "next_button"        => Label.NextButton,
          "fallback_functions" => functions,
          "disable_buttons"    => LanItems.operation != :add ?
            ["back_button"] :
            []
        }
      )
      Wizard.RestoreAbortButton

      Builtins.y2milestone("ShowAndRun: %1", ret)

      LanItems.Rollback if ret == :abort

      if ret != :back && ret != :abort
        ifcfgname = Ops.get_string(LanItems.getCurrentItem, "ifcfg", "")
        # general tab
        LanItems.startmode = Ops.get_string(@settings, "STARTMODE", "")
        if LanItems.startmode == "ifplugd"
          ifp_prio = Builtins.tostring(
            UI.QueryWidget(Id("IFPLUGD_PRIORITY"), :Value)
          )
          LanItems.ifplugd_priority = ifp_prio if ifp_prio != nil
        end
        LanItems.usercontrol = Ops.get_boolean(@settings, "USERCONTROL", false)

        if fw_is_installed
          zone = Ops.get_string(@settings, "FWZONE", "")
          SuSEFirewall4Network.ChangedByUser(true) if zone != @fwzone_initial
          SuSEFirewall4Network.ProtectByFirewall(ifcfgname, zone, zone != "")
        end

        LanItems.mtu = Ops.get_string(@settings, "MTU", "")

        # address tab
        if LanItems.operation == :add
          LanItems.device = NetworkInterfaces.device_num(ifcfgname)
          LanItems.type = NetworkInterfaces.GetTypeFromIfcfg(@settings)
          if LanItems.type == nil
            LanItems.type = NetworkInterfaces.device_type(ifcfgname)
          end
        end

        LanItems.bootproto = Ops.get_string(@settings, "BOOTPROTO", "")
        if LanItems.bootproto == "static" # #104494
          ip_changed = LanItems.ipaddr !=
            Ops.get_string(@settings, "IPADDR", "")
          if ip_changed
            Ops.set(Host.hosts, LanItems.ipaddr, [])
            Builtins.y2milestone("IP has changed")
            Host.SetModified
          end

          LanItems.ipaddr = Ops.get_string(@settings, "IPADDR", "")
          LanItems.netmask = Ops.get_string(@settings, "NETMASK", "")
          LanItems.prefix = Ops.get_string(@settings, "PREFIXLEN", "")
          LanItems.remoteip = Ops.get_string(@settings, "REMOTEIP", "")

          if @hostname_initial != Ops.get_string(@settings, "HOSTNAME", "") || ip_changed
            if Ops.get_string(@settings, "HOSTNAME", "") == ""
              Ops.set(Host.hosts, LanItems.ipaddr, [])
            else
              Host.Update(
                @hostname_initial,
                Ops.get_string(@settings, "HOSTNAME", ""),
                [Ops.get_string(@settings, "IPADDR", "")]
              )
            end
            Host.SetModified
          end
        else
          LanItems.ipaddr = ""
          LanItems.netmask = ""
          LanItems.remoteip = ""
          # fixed bug #73739 - if dhcp is used, dont set default gw statically
          # but also: reset default gw only if DHCP* is used, this branch covers
          #		 "No IP address" case, then default gw must stay (#460262)
          # and also: don't delete default GW for usb/pcmcia devices (#307102)
          if LanItems.isCurrentDHCP && !LanItems.isCurrentHotplug
            Routing.RemoveDefaultGw
          end
        end
      end

      if LanItems.type == "vlan"
        LanItems.vlan_etherdevice = Ops.get_string(@settings, "ETHERDEVICE", "")
        LanItems.vlan_id = Builtins.tostring(
          Ops.get_integer(@settings, "VLAN_ID", 0)
        )
      elsif LanItems.type == "br"
        LanItems.bridge_ports = Ops.get_string(@settings, "BRIDGE_PORTS", "")
      elsif Builtins.contains(["tun", "tap"], LanItems.type)
        LanItems.tunnel_set_persistent = Ops.get_string(
          @settings,
          "TUNNEL_SET_PERSISTENT",
          ""
        ) == "yes"
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



      # proceed with WLAN settings if appropriate, #42420
      if ret == :next && LanItems.type == "wlan" && LanItems.alias == ""
        ret = :wire
      end

      Routing.SetDevices(NetworkInterfaces.List("")) if ret == :routing


      deep_copy(ret)
    end
  end
end
