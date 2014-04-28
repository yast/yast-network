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
# File:        include/network/widgets.ycp
# Package:     Network configuration
# Summary:     Widgets for CWM
# Authors:     Martin Vidner <mvidner@suse.cz>
#
module Yast
  module NetworkWidgetsInclude

    def initialize_network_widgets(include_target)
      Yast.import "UI"

      textdomain "network"

      # Gradually all yast2-network UI will be converted to CWM
      # for easier maintenance.
      # This is just a start.

      Yast.import "IP"
      Yast.import "NetworkPopup"
      Yast.import "NetworkInterfaces"
      Yast.import "NetworkService"
      Yast.import "Lan"
      Yast.import "LanItems"

      Yast.include include_target, "network/complex.rb"

      @widget_descr = {
        # #23315
        "DIALPREFIXREGEX" => {
          "widget" => :textentry,
          # TextEntry label
          "label"  => _("&Dial Prefix Regular Expression"),
          "help" =>
            # dial prefix regex help
            _(
              "<p>When <b>Dial Prefix Regular Expression</b> is set, users can\n" +
                "change the dial prefix in KInternet provided that it matches the expression.\n" +
                "A recommended value is <tt>[09]?</tt>, allowing <tt>0</tt>, <tt>9</tt>,\n" +
                "and the empty prefix. If the expression is empty, users are not allowed\n" +
                "to change the prefix.</p>\n"
            )
        },
        # obsoleted by BOOTPROTO_*
        "BOOTPROTO"       => {
          "widget" => :radio_buttons,
          # radio button group label,method of setup
          "label"  => _(
            "Setup Method"
          ),
          # is this necessary?
          "items"  => [
            # radio button label
            ["dhcp", _("A&utomatic Address Setup (via DHCP)")],
            # radio button label
            ["static", _("S&tatic Address Setup")]
          ],
          "opt"    => [],
          "help"   => _("<p>H</p>")
        }
      }

      # This is the data for widget_descr["STARTMODE"].
      # It is separated because the list of items depends on the device type
      # and will be substituted dynamically.
      # Helps are rich text, but not paragraphs.
      @startmode_items = {
        # onboot, on and boot are aliases for auto
        # See NetworkInterfaces::CanonicalizeStartmode
        "auto" =>
          # is a part of the static help text
          {
            # Combo box option for Device Activation
            "label" => _(
              "At Boot Time"
            ),
            "help"  => ""
          },
        "off" =>
          # is a part of the static help text
          { "label" => _("Never"), "help" => "" },
        "managed" => {
          # Combo box option for Device Activation
          # DO NOT TRANSLATE NetworkManager, it is a program name
          "label" => _(
            "By NetworkManager"
          ),
          # help text for Device Activation
          # DO NOT TRANSLATE NetworkManager, it is a program name
          "help"  => _(
            "<b>By NetworkManager</b>: a desktop applet\ncontrols the interface. There is no need to set it up in YaST."
          )
        },
        "manual"  => {
          # Combo box option for Device Activation
          "label" => _("Manually"),
          # help text for Device Activation
          "help"  => _(
            "<p><b>Manually</b>: You control the interface manually\nvia 'ifup' or 'qinternet' (see 'User Controlled' below).</p>\n"
          )
        },
        "ifplugd" => {
          # Combo box option for Device Activation
          "label" => _(
            "On Cable Connection"
          ),
          # help text for Device Activation
          "help"  => _(
            "<b>On Cable Connection</b>:\n" +
              "The interface is watched for whether there is a physical\n" +
              "network connection. That means either the cable is connected or the\n" +
              "wireless interface can connect to an access point.\n"
          )
        },
        "hotplug" => {
          # Combo box option for Device Activation
          "label" => _("On Hotplug"),
          # help text for Device Activation
          "help"  => _(
            "With <b>On Hotplug</b>,\n" +
              "the interface is set up as soon as it is available. This is\n" +
              "nearly the same as 'At Boot Time', but does not result in an error at\n" +
              "boot time if the interface is not present.\n"
          )
        },
        "nfsroot" => {
          # Combo box option for Device Activation
          "label" => _("On NFSroot"),
          # help text for Device Activation
          "help"  => _(
            "Using <b>On NFSroot</b> is similar to <tt>auto</tt>. Interfaces with this startmode will never\n" +
              "be shut down via <tt>rcnetwork stop</tt>. <tt>ifdown <iface></tt> is still available.\n" +
              "Use this if you have an NFS or iSCSI root filesystem.\n"
          )
        },
        "nfsroot" => {
          # Combo box option for Device Activation
          "label" => _("On NFSroot"),
          # help text for Device Activation
          "help"  => _(
            "Using <b>On NFSroot</b> is nearly like 'auto'. But interfaces with this startmode will never\n" +
              "be shut down via 'rcnetwork stop'. 'ifdown <iface>' still works.\n" +
              "Use this when you have a nfs or iscsi root filesystem.\n"
          )
        }
      }
    end

    # Validator for IP adresses, no_popup
    # @param [String] key	the widget being validated
    # @param [Hash] event	the event being handled
    # @return whether valid
    def ValidateIP(key, event)
      value = Convert.to_string(UI.QueryWidget(Id(key), :Value))
      return IP.Check(value) if value != ""
      true
    end

    def handleStartmode(key, event)
      UI.ChangeWidget(
        Id("IFPLUGD_PRIORITY"),
        :Enabled,
        UI.QueryWidget(Id("STARTMODE"), :Value) == "ifplugd"
      )
      nil
    end

    def MakeStartmode(ids)
      ids = deep_copy(ids)
      ret = {
        "widget" => :combobox,
        # Combo box label - when to activate device (e.g. on boot, manually, never,..)
        "label"  => _("Activate &device"),
        "opt"    => [:notify],
        "handle" => fun_ref(method(:handleStartmode), "symbol (string, map)"),
        "help"   =>
          # Device activation main help. The individual parts will be
          # substituted as %1
          _(
            "<p><b><big>Device Activation</big></b></p> \n" +
              "<p>Choose when to bring up the network interface. <b>At Boot Time</b> activates it during system boot, \n" +
              "<b>Never</b> does not start the device.\n" +
              "%1</p>\n"
          )
      }
      helps = ""
      items = Builtins.maplist(ids) do |id|
        helps = Ops.add(
          Ops.add(helps, " "),
          Ops.get(@startmode_items, [id, "help"], "")
        )
        [id, Ops.get(@startmode_items, [id, "label"], "")]
      end

      Ops.set(
        ret,
        "help",
        Builtins.sformat(Ops.get_string(ret, "help", "%1"), helps)
      )
      Ops.set(ret, "items", items)
      deep_copy(ret)
    end

    def init_ipoib_mode_widget(key)

      ipoib_mode = LanItems.ipoib_mode

      return unless LanItems.ipoib_modes.keys.include?(ipoib_mode)

      UI.ChangeWidget(
        Id(key),
        :CurrentButton,
        ipoib_mode
      )
    end

    def store_ipoib_mode_widget(key, event)
      LanItems.ipoib_mode = UI.QueryWidget(Id(key), :CurrentButton)
    end

    def ipoib_mode_widget
      {
        "widget" => :radio_buttons,
        "items"  => LanItems.ipoib_modes.to_a,
        "label"  => _("IPoIB device mode"),
        "opt"    => [:hstretch],
        "init"   => fun_ref(method(:init_ipoib_mode_widget), "void (string)"),
        "store"  => fun_ref(method(:store_ipoib_mode_widget), "void (string, map)")
      }
    end

    def firewall_widget
      if SuSEFirewall4Network.IsInstalled
        SuSEFirewall4Network.FirewallZonesComboBoxItems
      else
        [["", _("Firewall is not installed.")]]
      end

    end

    def common_mtu_items
      [
        # translators: MTU value description (size in bytes, desc)
        ["1500", _("1500 (Ethernet, DSL broadband)")],
        ["1492", _("1492 (PPPoE broadband)")],
        ["576", _("576 (dial-up)")]
      ]
    end

    def ipoib_mtu_items
      [
        # translators: MTU value description (size in bytes, desc)
        ["65520", _("65520 (IPoIB in connected mode)")],
        ["2044", _("2044 (IPoIB in datagram mode)")]
      ]
    end

    def mtu_widget
      {
        "widget" => :combobox,
        # textentry label, Maximum Transfer Unit
        "label"  => _("Set &MTU"),
        "opt"    => [:hstretch, :editable],
        "items"  => [],
        "help"   => @help["mtu"] || ""
      }
    end

    # Initialize the NetworkManager widget
    # @param [String] key id of the widget
    def ManagedInit(key)
      value = "managed" if NetworkService.is_network_manager
      value = "ifup"    if NetworkService.is_netconfig
      value = "wicked"  if NetworkService.is_wicked

      UI.ChangeWidget(
        Id("managed"),
        :Enabled,
        NetworkService.is_backend_available(:network_manager))
      UI.ChangeWidget(
        Id("ifup"),
        :Enabled,
        NetworkService.is_backend_available(:netconfig))
      UI.ChangeWidget(
        Id("wicked"),
        :Enabled,
        NetworkService.is_backend_available(:wicked))

      UI.ChangeWidget(Id(key), :CurrentButton, value)

      nil
    end

    # Store the NetworkManager widget
    # @param [String] key	id of the widget
    # @param [Hash] event	the event being handled
    def ManagedStore(key, event)
      new_backend = UI.QueryWidget(Id(key), :CurrentButton)

      case new_backend
        when "ifup"
          NetworkService.use_netconfig
        when "managed"
          NetworkService.use_network_manager
        when "wicked"
          NetworkService.use_wicked
      end

      if NetworkService.Modified
        LanItems.SetModified

        if Stage.normal && NetworkService.is_network_manager
          Popup.AnyMessage(
            _("Applet needed"),
            _(
              "NetworkManager is controlled by desktop applet\n" +
              "(KDE plasma widget and nm-applet for GNOME).\n" +
              "Be sure it's running and if not, start it manually."
           ))
        end
      end

      nil
    end

    def managed_widget
      {
        "widget" => :radio_buttons,
        # radio button group label, method of setup
        "label"  => _("Network Setup Method"),
        "items"  => [
          # radio button label
          # the user can control the network with the NetworkManager
          # program
          [
            "managed",
            _("&User Controlled with NetworkManager")
          ],
          # radio button label
          # ifup is a program name
          [
            "ifup",
            _("&Traditional Method with ifup")
          ],
          # radio button label
          # wicked is network configuration backend like netconfig
          [
            "wicked",
            _("Controlled by &wicked")
          ],
        ],
        "opt"    => [],
        "help"   => Ops.get_string(@help, "managed", ""),
        "init"   => fun_ref(method(:ManagedInit), "void (string)"),
        "store"  => fun_ref(method(:ManagedStore), "void (string, map)")
      }
    end

    def initIPv6(key)
      UI.ChangeWidget(Id(:ipv6), :Value, Lan.ipv6 ? true : false)

      nil
    end

    def handleIPv6(key, event)
      event = deep_copy(event)
      if Ops.get_string(event, "EventReason", "") == "ValueChanged"
        Lan.SetIPv6(Convert.to_boolean(UI.QueryWidget(Id(:ipv6), :Value)))
      end
      nil
    end

    def storeIPv6(key, event)
      event = deep_copy(event)
      if Convert.to_boolean(UI.QueryWidget(Id(:ipv6), :Value))
        Lan.SetIPv6(true)
      else
        Lan.SetIPv6(false)
      end

      nil
    end

    def ipv6_widget
      {
        "widget"        => :custom,
        "custom_widget" => Frame(
          _("IPv6 Protocol Settings"),
          Left(CheckBox(Id(:ipv6), Opt(:notify), _("Enable IPv6")))
        ),
        "opt"           => [],
        "help"          => Ops.get_string(@help, "ipv6", ""),
        "init"          => fun_ref(method(:initIPv6), "void (string)"),
        "handle"        => fun_ref(
          method(:handleIPv6),
          "symbol (string, map)"
        ),
        "store"         => fun_ref(method(:storeIPv6), "void (string, map)")
      }
    end

    def GetDeviceDescription(device_id)
      device_name = NetworkInterfaces.GetValue(device_id, "NAME")
      if device_name == nil || device_name == ""
        #TRANSLATORS: Informs that device name is not known
        device_name = _("Unknown device")
      end
      Builtins.y2milestone("device_name %1", device_name)
      #avoid too long device names
      #if (size(device_name) > 30) {
      #    device_name = substring (device_name, 0, 27) + "...";
      #}
      ip_addr = Builtins.issubstring(
        NetworkInterfaces.GetValue(device_id, "BOOTPROTO"),
        "dhcp"
      ) ?
        # TRANSLATORS: Part of label, device with IP address assigned by DHCP
        _("DHCP address") :
        # TRANSLATORS: Part of label, device with static IP address
        NetworkInterfaces.GetValue(device_id, "IPADDR")
      if ip_addr == nil || ip_addr == ""
        #TRANSLATORS: Informs that no IP has been assigned to the device
        ip_addr = _("No IP address assigned")
      end
      output = Builtins.sformat(
        _("%1 \n%2 - %3"),
        device_name,
        NetworkInterfaces.GetDeviceTypeName(device_id),
        ip_addr
      )
      output
    end



    def getInternetItems
      NetworkInterfaces.Read
      items = NetworkInterfaces.List("")
      items = Builtins.filter(items) { |i| i != "lo" }
      deep_copy(items)
    end

    def getNetDeviceItems
      NetworkInterfaces.Read
      ifaces = NetworkInterfaces.List("eth")
      Builtins.y2debug("ifaces=%1", ifaces)
      ifaces = Convert.convert(
        Builtins.union(ifaces, NetworkInterfaces.List("eth-pcmcia")),
        :from => "list",
        :to   => "list <string>"
      )
      Builtins.y2debug("ifaces=%1", ifaces)
      ifaces = Convert.convert(
        Builtins.union(ifaces, NetworkInterfaces.List("eth-usb")),
        :from => "list",
        :to   => "list <string>"
      )
      ifaces = Convert.convert(
        Builtins.union(ifaces, NetworkInterfaces.List("wlan")),
        :from => "list",
        :to   => "list <string>"
      ) # #186102
      Builtins.y2debug("ifaces=%1", ifaces)
      deep_copy(ifaces)
    end

    def getDeviceContens(selected)
      VBox(
        VSpacing(0.5),
        HBox(
          HSpacing(3),
          MinWidth(
            30,
            Label(
              Id(:net_device),
              Opt(:hstretch),
              GetDeviceDescription(selected)
            )
          ),
          HSpacing(1),
          PushButton(Id(:net_expert), _("&Change Device"))
        ),
        VSpacing(0.5)
      )
    end


    def initDevice(items)
      items = deep_copy(items)
      #If only one device is present, disable "Change device" button
      if Ops.less_or_equal(Builtins.size(items), 1)
        UI.ChangeWidget(Id(:net_expert), :Enabled, false)
      end

      nil
    end

    def enableDevices(enable)
      UI.ChangeWidget(:net_device, :Enabled, enable)
      UI.ChangeWidget(:net_expert, :Enabled, enable)

      nil
    end

    def refreshDevice(via_device)
      UI.ChangeWidget(:net_device, :Value, GetDeviceDescription(via_device))

      nil
    end

    def handleDevice(items, selected)
      items = deep_copy(items)
      # popup dialog title
      via_device = NetworkPopup.ChooseItem(
        _("Network Device Select"),
        items,
        selected
      )
      if via_device != nil
        UI.ChangeWidget(:net_device, :Value, GetDeviceDescription(via_device))
        Builtins.y2milestone("selected network device :%1", via_device)
        selected = via_device
      end
      selected
    end

    # Builds content for slave configuration dialog (used e.g. when configuring
    # bond slaves) according the given list of itemIds (see LanItems::Items)
    #
    # @param [Array<Fixnum>] itemIds           list of indexes into LanItems::Items
    # @param [Array<String>] enslavedIfaces    list of device names of already enslaved devices
    def CreateSlaveItems(itemIds, enslavedIfaces)
      itemIds = deep_copy(itemIds)
      enslavedIfaces = deep_copy(enslavedIfaces)
      items = []

      Builtins.foreach(itemIds) do |itemId|
        description = ""
        dev_name = LanItems.GetDeviceName(itemId)
        ifcfg = LanItems.GetDeviceMap(itemId)
        next if IsEmpty(dev_name)
        ifcfg = { "dev_name" => dev_name } if ifcfg == nil
        dev_type = LanItems.GetDeviceType(itemId)
        if Builtins.contains(["tun", "tap"], dev_type)
          description = NetworkInterfaces.GetDevTypeDescription(dev_type, true)
        else
          description = BuildDescription(
            "",
            "",
            ifcfg,
            [Ops.get_map(LanItems.GetLanItem(itemId), "hwinfo", {})]
          )

          # this conditions origin from bridge configuration
          # if enslaving a configured device then its configuration is rewritten
          # to "0.0.0.0/32"
          if Ops.get_string(ifcfg, "IPADDR", "") != "0.0.0.0"
            description = Builtins.sformat("%1 (%2)", description, "configured")
          end
        end
        selected = Builtins.contains(enslavedIfaces, dev_name)
        items = Builtins.add(
          items,
          Item(
            Id(dev_name),
            Builtins.sformat("%1 - %2", dev_name, description),
            selected
          )
        )
      end

      deep_copy(items)
    end
  end
end
