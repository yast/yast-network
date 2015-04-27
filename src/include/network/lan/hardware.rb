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
# File:	include/network/lan/hardware.ycp
# Package:	Network configuration
# Summary:	Hardware dialogs
# Authors:	Michal Svec <msvec@suse.cz>
#

require "network/edit_nic_name"

module Yast
  module NetworkLanHardwareInclude
    def initialize_network_lan_hardware(include_target)
      Yast.import "UI"

      textdomain "network"

      Yast.import "Arch"
      Yast.import "CWM"
      Yast.import "Label"
      Yast.import "Lan"
      Yast.import "NetworkInterfaces"
      Yast.import "Popup"
      Yast.import "Wizard"
      Yast.import "LanItems"
      Yast.include include_target, "network/summary.rb"
      Yast.include include_target, "network/routines.rb"
      Yast.include include_target, "network/lan/cards.rb"

      @hardware = nil


      @widget_descr_hardware = {
        "HWDIALOG" => {
          "widget"            => :custom,
          "custom_widget"     => ReplacePoint(Id(:hw_content), Empty()),
          "init"              => fun_ref(method(:initHwDialog), "void (string)"),
          "handle"            => fun_ref(method(:handleHW), "symbol (string, map)"),
          "store"             => fun_ref(method(:storeHW), "void (string, map)"),
          "validate_type"     => :function,
          "validate_function" => fun_ref(method(:validate_hw), "boolean (string, map)"),
          "help"              => initHelp
        }
      }
    end

    # Determines if the dialog is used for adding new device or for editing existing one.
    #
    # Some widgets are disabled when creating new device. Also, when editing existing device, it is not possible
    # to e.g. change device type.
    #
    # @return false if hardware widgets are embedded into another dialog, otherwise true.
    def isNewDevice
      LanItems.operation == :add
    end

    # Dynamic initialization of help text.
    #
    # @return content of the help
    def initHelp
      # Manual network card setup help 1/4
      hw_help = _(
        "<p>Set up hardware-specific options for \nyour network device here.</p>\n"
      )

      if isNewDevice
        # Manual network card setup help 2/4
        # translators: do not translated udev, MAC, BusID
        hw_help = Ops.add(
          hw_help,
          _(
            "<p><b>Device Type</b>. Various device types are available, select \none according your needs.</p>"
          )
        )
      else
        hw_help = Ops.add(
          Ops.add(
            hw_help,
            _(
              "<p><b>Udev Rules</b> are rules for the kernel device manager that allow\n" +
                "associating the MAC address or BusID of the network device with its name (for\n" +
                "example, eth1, wlan0 ) and assures a persistent device name upon reboot.\n"
            )
          ),
          _(
            "<p><b>Show visible port identification</b> allows you to physically identify now configured NIC. \n" +
              "Set appropriate time, click <b>Blink</b> and LED diodes on you NIC will start blinking for selected time.\n" +
              "</p>"
          )
        )
      end

      # Manual network card setup help 2/4
      hw_help = Ops.add(
        Ops.add(
          Ops.add(
            hw_help,
            _(
              "<p><b>Kernel Module</b>. Enter the kernel module (driver) name \n" +
                "for your network device here. If the device is already configured, see if there is more than one driver available for\n" +
                "your device in the drop-down list. If necessary, choose a driver from the list, but usually the default value works.</p>\n"
            )
          ),
          # Manual networ card setup help 3/4
          _(
            "<p>Additionally, specify <b>Options</b> for the kernel module. Use this\n" +
              "format: <i>option</i>=<i>value</i>. Each entry should be space-separated, for example: <i>io=0x300 irq=5</i>. <b>Note:</b> If two cards are \n" +
              "configured with the same module name, the options will be merged while saving.</p>\n"
          )
        ),
        _(
          "<p>If you specify options via <b>Ethtool options</b>, ifup will call ethtool with these options.</p>\n"
        )
      )

      if isNewDevice && !Arch.s390
        # Manual dialog help 4/4
        hw_help = Ops.add(
          hw_help,
          _(
            "<p>If you have a <b>PCMCIA</b> network card, select PCMCIA.\nIf you have a <b>USB</b> network card, select USB.</p>\n"
          )
        )
      end

      if Arch.s390
        # overwrite help
        # Manual dialog help 5/4
        hw_help = _(
          "<p>Here, set up your networking device. The values will be\nwritten to <i>/etc/modprobe.conf</i> or <i>/etc/chandev.conf</i>.</p>\n"
        ) +
          # Manual dialog help 6/4
          _(
            "<p>Options for the module should be written in the format specified\nin the <b>IBM Device Drivers and Installation Commands</b> manual.</p>"
          )
      end

      hw_help
    end

    def initHardware
      @hardware = {}
      Ops.set(@hardware, "hotplug", LanItems.hotplug)
      Builtins.y2milestone("hotplug=%1", LanItems.hotplug)
      Ops.set(
        @hardware,
        "modules_from_hwinfo",
        LanItems.GetItemModules(Ops.get_string(@hardware, "modul", ""))
      )

      Ops.set(@hardware, "type", LanItems.type)
      if Ops.get_string(@hardware, "type", "") == ""
        Builtins.y2error("Shouldn't happen -- type is empty. Assuming eth.")
        Ops.set(@hardware, "type", "eth")
      end
      Ops.set(
        @hardware,
        "realtype",
        NetworkInterfaces.RealType(
          Ops.get_string(@hardware, "type", ""),
          Ops.get_string(@hardware, "hotplug", "")
        )
      )

      #Use rather LanItems::device, so that device number is initialized correctly at all times (#308763)
      Ops.set(@hardware, "device", LanItems.device)

      driver = Ops.get_string(LanItems.getCurrentItem, ["udev", "driver"], "")


      Ops.set(
        @hardware,
        "default_device",
        IsNotEmpty(driver) ?
          driver :
          Ops.get_string(LanItems.getCurrentItem, ["hwinfo", "module"], "")
      )

      Ops.set(
        @hardware,
        "options",
        Ops.get_string(
          LanItems.driver_options,
          Ops.get_string(@hardware, "default_device", ""),
          ""
        )
      )

      # #38213, remember device id when we switch back from pcmcia/usb
      Ops.set(
        @hardware,
        "non_hotplug_device_id",
        Ops.get_string(@hardware, "device", "")
      )

      # FIXME duplicated in address.ycp
      Ops.set(@hardware, "device_types", NetworkInterfaces.GetDeviceTypes)

      if Builtins.issubstring(
          Ops.get_string(@hardware, "device", ""),
          "bus-pcmcia"
        )
        Ops.set(@hardware, "hotplug", "pcmcia")
      elsif Builtins.issubstring(
          Ops.get_string(@hardware, "device", ""),
          "bus-usb"
        )
        Ops.set(@hardware, "hotplug", "usb")
      end

      Builtins.y2milestone("hotplug=%1", LanItems.hotplug)

      Ops.set(
        @hardware,
        "devices",
        LanItems.FreeDevices(Ops.get_string(@hardware, "realtype", ""))
      ) # TODO: id-, bus-, ... here
      if !Builtins.contains(
          Ops.get_list(@hardware, "devices", []),
          Ops.get_string(@hardware, "device", "")
        )
        Ops.set(
          @hardware,
          "devices",
          Builtins.prepend(
            Ops.get_list(@hardware, "devices", []),
            Ops.get_string(@hardware, "device", "")
          )
        )
      end

      Ops.set(
        @hardware,
        "no_hotplug",
        Ops.get_string(@hardware, "hotplug", "") == ""
      )
      Ops.set(
        @hardware,
        "no_hotplug_dummy",
        Ops.get_boolean(@hardware, "no_hotplug", false) &&
          Ops.get_string(@hardware, "type", "") != "dummy"
      )
      Ops.set(@hardware, "ethtool_options", LanItems.ethtool_options)

      nil
    end

    def initHwDialog(text)
      # Manual dialog caption
      caption = _("Manual Network Card Configuration")

      initHardware

      hotplug_type = @hardware["hotplug"] || ""
      hw_type = @hardware["type"] || ""

      _CheckBoxes = HBox(
        HSpacing(1.5),
        # CheckBox label
        CheckBox(
          Id(:pcmcia),
          Opt(:notify),
          _("&PCMCIA"),
          hotplug_type == "pcmcia"
        ),
        HSpacing(1.5),

        # CheckBox label
        CheckBox(
          Id(:usb),
          Opt(:notify),
          _("&USB"),
          hotplug_type == "usb"
        ),
        HSpacing(1.5)
      )

      # Placeholders (translations)
      _XBox = HBox(
        # ComboBox label
        ComboBox(Id(:hotplug), Opt(:notify), _("&Hotplug Type"), []),
        # CheckBox label
        CheckBox(
          Id(:pci),
          Opt(:notify),
          _("P&CI"),
          hotplug_type == "pci"
        ),
        HSpacing(1.5)
      )

      # Disable PCMCIA and USB checkboxex on Edit and s390
      _CheckBoxes = VSpacing(0) if !isNewDevice || Arch.s390

      # #116211 - allow user to change modules from list
      # Frame label
      _KernelBox = Frame(
        _("&Kernel Module"),
        HBox(
          HSpacing(0.5),
          VBox(
            VSpacing(0.4),
            HBox(
              # Text entry label
              ComboBox(
                Id(:modul),
                Opt(:editable),
                _("&Module Name"),
                @hardware["modules_from_hwinfo"] || []
              ),
              HSpacing(0.5),
              InputField(
                Id(:options),
                Opt(:hstretch),
                Label.Options,
                @hardware["options"] || ""
              )
            ),
            VSpacing(0.4),
            _CheckBoxes,
            VSpacing(0.4)
          ),
          HSpacing(0.5)
        )
      )


      _DeviceNumberBox = ReplacePoint(
        Id(:rnum),
        # TextEntry label
        ComboBox(
          Id(:ifcfg_name),
          Opt(:editable, :hstretch),
          _("&Configuration Name"),
          [@hardware["device"] || ""]
        )
      )

      # Manual dialog contents
      _TypeNameWidgets = VBox(
        VSpacing(0.2),
        HBox(
          HSpacing(0.5),
          ComboBox(
            Id(:type),
            Opt(:hstretch, :notify),
            # ComboBox label
            _("&Device Type"),
            BuildTypesList(
              @hardware["device_types"] || [],
              hw_type
            )
          ),
          HSpacing(1.5),
          _DeviceNumberBox,
          HSpacing(0.5)
        )
      )

      _UdevWidget =
        Frame(
          _("Udev Rules"),
          HBox(
            InputField(Id(:device_name), Opt(:hstretch), _("Device Name"), ""),
            PushButton(Id(:change_udev), _("Change"))
          )
        )

      if !isNewDevice
        _TypeNameWidgets = Empty()
      else
        _UdevWidget = Empty()
      end

      _BlinkCard = Frame(
        _("Show Visible Port Identification"),
        HBox(
          # translators: how many seconds will card be blinking
          IntField(
            Id(:blink_time),
            "%s:" % _("Seconds"),
            0,
            100,
            5
          ),
          PushButton(Id(:blink), _("Blink"))
        )
      )

      _EthtoolWidget = Frame(
        _("Ethtool Options"),
        HBox(
          InputField(
            Id(:ethtool_opts),
            Opt(:hstretch),
            _("Options"),
            @hardware["ethtool_options"] || ""
          )
        )
      )

      contents = VBox(
        HBox(_UdevWidget, HStretch(), isNewDevice ? Empty() : _BlinkCard),
        _TypeNameWidgets,
        _KernelBox,
        _EthtoolWidget,
        VStretch()
      )

      UI.ReplaceWidget(:hw_content, contents)
      UI.ChangeWidget(
        :modul,
        :Value,
        @hardware["default_device"] || ""
      )
      UI.ChangeWidget(
        Id(:modul),
        :Enabled,
        !!@hardware["no_hotplug_dummy"]
      )
      ChangeWidgetIfExists(
        Id(:list),
        :Enabled,
        !!@hardware["no_hotplug_dummy"]
      )
      ChangeWidgetIfExists(
        Id(:hwcfg),
        :Enabled,
        !!@hardware["no_hotplug"]
      )
      ChangeWidgetIfExists(
        Id(:usb),
        :Enabled,
        (hotplug_type == "usb" || hotplug_type == "") &&
        hw_type != "dummy"
      )
      ChangeWidgetIfExists(
        Id(:pcmcia),
        :Enabled,
        (hotplug_type == "pcmcia" || hotplug_type == "") &&
        hw_type != "dummy"
      )

      device_name = LanItems.current_udev_name

      ChangeWidgetIfExists(Id(:device_name), :Enabled, false)
      ChangeWidgetIfExists(Id(:device_name), :Value, device_name)

      ChangeWidgetIfExists(Id(:type), :Enabled, false) if !isNewDevice
      ChangeWidgetIfExists(
        Id(:ifcfg_name),
        :ValidChars,
        NetworkInterfaces.ValidCharsIfcfg
      )

      nil
    end



    # Call back for a manual selection from the list
    # @return dialog result
    def SelectionDialog
      type = LanItems.type
      selected = 0

      hwlist = Ops.get_list(@NetworkCards, type, [])
      cards = hwlist2items(hwlist, 0)

      # Manual selection caption
      caption = _("Manual Network Card Selection")

      # Manual selection help
      helptext = _(
        "<p>Select the network card to configure. Search\nfor a particular network card by entering the name in the search entry.</p>"
      )

      # Manual selection contents
      contents = VBox(
        VSpacing(0.5),
        # Selection box label
        ReplacePoint(
          Id(:rp),
          SelectionBox(Id(:cards), _("&Network Card"), cards)
        ),
        VSpacing(0.5),
        # Text entry field
        InputField(Id(:search), Opt(:hstretch, :notify), _("&Search")),
        VSpacing(0.5)
      )

      Wizard.SetContentsButtons(
        caption,
        contents,
        helptext,
        Label.BackButton,
        Label.OKButton
      )

      UI.SetFocus(Id(:cards))

      ret = nil
      while true
        ret = UI.UserInput

        if ret == :abort || ret == :cancel
          if ReallyAbort()
            break
          else
            next
          end
        elsif ret == :search
          entry = Convert.to_string(UI.QueryWidget(Id(:search), :Value))

          l = Builtins.filter(
            Convert.convert(cards, :from => "list", :to => "list <term>")
          ) do |e|
            Builtins.tolower(
              Builtins.substring(
                Ops.get_string(e, 1, ""),
                0,
                Builtins.size(entry)
              )
            ) ==
              Builtins.tolower(entry)
          end

          selected = 0 if Builtins.size(entry) == 0
          if Ops.greater_than(Builtins.size(l), 0)
            selected = Ops.get_integer(l, [0, 0, 0], 0)
          end

          cards = []
          cards = hwlist2items(hwlist, selected)

          # Selection box title
          UI.ReplaceWidget(
            Id(:rp),
            SelectionBox(Id(:cards), _("&Network Card"), cards)
          )
        elsif ret == :back
          break
        elsif ret == :next
          # FIXME: check_*
          break
        else
          Builtins.y2error("Unexpected return code: %1", ret)
          next
        end
      end

      if ret == :next
        selected = Convert.to_integer(UI.QueryWidget(Id(:cards), :CurrentItem))
        selected = 0 if selected == nil
        card = Ops.get(hwlist, selected, {})
        LanItems.description = Ops.get_string(card, "name", "") 
      end

      deep_copy(ret)
    end

    # Dialog for editing nic's udev rules.
    #
    # @return nic name. New one if `ok, old one otherwise.
    def EditUdevRulesDialog
      edit_name_dlg = EditNicName.new
      edit_name_dlg.run
    end

    def handleHW(key, event)
      event = deep_copy(event)
      LanItems.Rollback if Ops.get(event, "ID") == :cancel
      ret = nil
      if Ops.get_string(event, "EventReason", "") == "ValueChanged" ||
          Ops.get_string(event, "EventReason", "") == "Activated"
        ret = Ops.get_symbol(event, "WidgetID")
      end
      SelectionDialog() if ret == :list
      if ret == :pcmcia || ret == :usb || ret == :type
        if UI.WidgetExists(Id(:pcmcia)) || UI.WidgetExists(Id(:usb))
          if UI.QueryWidget(Id(:pcmcia), :Value) == true
            Ops.set(@hardware, "hotplug", "pcmcia")
          elsif UI.QueryWidget(Id(:usb), :Value) == true
            Ops.set(@hardware, "hotplug", "usb")
          else
            Ops.set(@hardware, "hotplug", "")
          end
        end
        Builtins.y2debug("hotplug=%1", Ops.get_string(@hardware, "hotplug", ""))

        if UI.WidgetExists(Id(:type))
          Ops.set(
            @hardware,
            "type",
            Convert.to_string(UI.QueryWidget(Id(:type), :Value))
          )
          Ops.set(
            @hardware,
            "realtype",
            NetworkInterfaces.RealType(
              Ops.get_string(@hardware, "type", ""),
              Ops.get_string(@hardware, "hotplug", "")
            )
          )
          UI.ChangeWidget(
            Id(:ifcfg_name),
            :Items,
            LanItems.FreeDevices(@hardware["realtype"]).map do |index|
              @hardware["realtype"] + index
            end
          )
        end
        Builtins.y2debug("type=%1", Ops.get_string(@hardware, "type", ""))
        Builtins.y2debug(
          "realtype=%1",
          Ops.get_string(@hardware, "realtype", "")
        )

        if Ops.get_string(@hardware, "type", "") == "usb"
          UI.ChangeWidget(Id(:usb), :Value, true)
          Ops.set(@hardware, "hotplug", "usb")
        end

        Ops.set(
          @hardware,
          "no_hotplug",
          Ops.get_string(@hardware, "hotplug", "") == ""
        )
        Ops.set(
          @hardware,
          "no_hotplug_dummy",
          Ops.get_boolean(@hardware, "no_hotplug", false) &&
            Ops.get_string(@hardware, "type", "") != "dummy"
        )
        UI.ChangeWidget(
          Id(:modul),
          :Enabled,
          Ops.get_boolean(@hardware, "no_hotplug_dummy", false)
        )
        UI.ChangeWidget(
          Id(:options),
          :Enabled,
          Ops.get_boolean(@hardware, "no_hotplug_dummy", false)
        )
        ChangeWidgetIfExists(
          Id(:list),
          :Enabled,
          Ops.get_boolean(@hardware, "no_hotplug_dummy", false)
        )
        ChangeWidgetIfExists(
          Id(:hwcfg),
          :Enabled,
          Ops.get_boolean(@hardware, "no_hotplug", false)
        )
        ChangeWidgetIfExists(
          Id(:usb),
          :Enabled,
          (Ops.get_string(@hardware, "hotplug", "") == "usb" ||
            Ops.get_string(@hardware, "hotplug", "") == "") &&
            Ops.get_string(@hardware, "type", "") != "dummy"
        )
        ChangeWidgetIfExists(
          Id(:pcmcia),
          :Enabled,
          (Ops.get_string(@hardware, "hotplug", "") == "pcmcia" ||
            Ops.get_string(@hardware, "hotplug", "") == "") &&
            Ops.get_string(@hardware, "type", "") != "dummy"
        )
        Ops.set(
          @hardware,
          "device",
          Convert.to_string(UI.QueryWidget(Id(:ifcfg_name), :Value))
        )
        if Ops.get_string(@hardware, "device", "") != "bus-usb" &&
            Ops.get_string(@hardware, "device", "") != "bus-pcmcia"
          Ops.set(
            @hardware,
            "non_hotplug_device_id",
            Ops.get_string(@hardware, "device", "")
          )
        end

        if Ops.get_string(@hardware, "hotplug", "") == "usb"
          Ops.set(@hardware, "device", "bus-usb")
        elsif Ops.get_string(@hardware, "hotplug", "") == "pcmcia"
          Ops.set(@hardware, "device", "bus-pcmcia")
        else
          Ops.set(
            @hardware,
            "device",
            Ops.get_string(@hardware, "non_hotplug_device_id", "")
          )
        end

        UI.ChangeWidget(
          Id(:ifcfg_name),
          :Value,
          Ops.get_string(@hardware, "device", "")
        )

        if Arch.s390
          drvtype = DriverType(Ops.get_string(@hardware, "type", ""))

          if Builtins.contains(["lcs", "qeth", "ctc"], drvtype)
            Ops.set(@hardware, "modul", drvtype)
          elsif drvtype == "iucv"
            Ops.set(@hardware, "modul", "netiucv")
          end
          UI.ChangeWidget(
            Id(:modul),
            :Value,
            Ops.get_string(@hardware, "modul", "")
          )
        end
        if Ops.get_string(@hardware, "type", "") == "xp"
          Ops.set(@hardware, "modul", "xpnet")
          UI.ChangeWidget(
            Id(:modul),
            :Value,
            Ops.get_string(@hardware, "modul", "")
          )
        elsif Ops.get_string(@hardware, "type", "") == "dummy" # #44582
          Ops.set(@hardware, "modul", "dummy")

          if UI.WidgetExists(Id(:hwcfg)) # bnc#767946
            Ops.set(
              @hardware,
              "hwcfg",
              Convert.to_string(UI.QueryWidget(Id(:hwcfg), :Value))
            )
            Ops.set(
              @hardware,
              "options",
              Builtins.sformat(
                "-o dummy-%1",
                Ops.get_string(@hardware, "hwcfg", "")
              )
            )
          end

          UI.ChangeWidget(
            Id(:modul),
            :Value,
            Ops.get_string(@hardware, "modul", "")
          )
          UI.ChangeWidget(
            Id(:options),
            :Value,
            Ops.get_string(@hardware, "options", "")
          )
        elsif Builtins.contains(
            ["bond", "vlan", "br", "tun", "tap"],
            Ops.get_string(@hardware, "type", "")
          )
          UI.ChangeWidget(Id(:hwcfg), :Enabled, false)
          UI.ChangeWidget(Id(:modul), :Enabled, false)
          UI.ChangeWidget(Id(:options), :Enabled, false)
          UI.ChangeWidget(Id(:pcmcia), :Enabled, false)
          UI.ChangeWidget(Id(:usb), :Enabled, false)
          UI.ChangeWidget(Id(:list), :Enabled, false)

          UI.ChangeWidget(Id(:hwcfg), :Value, "")
          UI.ChangeWidget(Id(:modul), :Value, "")
          UI.ChangeWidget(Id(:options), :Value, "")
        end
      end
      if ret == :change_udev
        UI.ChangeWidget(:device_name, :Value, EditUdevRulesDialog())
      end
      if ret == :blink
        device = LanItems.device
        timeout = Builtins.tointeger(UI.QueryWidget(:blink_time, :Value))
        Builtins.y2milestone(
          "blink, blink ... %1 seconds on %2 device",
          timeout,
          device
        )
        cmd = Builtins.sformat("ethtool -p %1 %2", device, timeout)
        Builtins.y2milestone(
          "%1 : %2",
          cmd,
          SCR.Execute(path(".target.bash_output"), cmd)
        )
      end
      nil
    end

    def devname_from_hw_dialog
      UI.QueryWidget(Id(:ifcfg_name), :Value)
    end

    def validate_hw(key, event)
      nm = devname_from_hw_dialog

      if UsedNicName(nm)
        Popup.Error(
          Builtins.sformat(
            _(
              "Configuration name %1 already exists.\nChoose a different one."
            ),
            nm
          )
        )
        UI.SetFocus(Id(:ifcfg_name))

        return false
      end

      return true
    end

    def storeHW(key, event)
      if isNewDevice
        nm = devname_from_hw_dialog
        LanItems.type = UI.QueryWidget(Id(:type), :Value)
        LanItems.device = nm

        NetworkInterfaces.Name = nm
        Ops.set(LanItems.Items, [LanItems.current, "ifcfg"], nm)
        # Initialize udev map, so that setDriver (see below) sets correct module
        Ops.set(LanItems.Items, [LanItems.current, "udev"], {})
        # FIXME: for interfaces with no hwinfo don't propose ifplugd
        if Builtins.size(Ops.get_map(LanItems.getCurrentItem, "hwinfo", {})) == 0
          Builtins.y2milestone(
            "interface without hwinfo, proposing STARTMODE=auto"
          )
          LanItems.startmode = "auto"
        end
        if LanItems.type == "vlan"
          # for vlan devices named vlanN pre-set vlan_id to N, otherwise default to 0
          LanItems.vlan_id = "#{nm["vlan".size].to_i}"
        end
      end

      driver = Convert.to_string(UI.QueryWidget(:modul, :Value))
      LanItems.setDriver(driver)
      Ops.set(
        LanItems.driver_options,
        driver,
        Convert.to_string(UI.QueryWidget(:options, :Value))
      )
      LanItems.ethtool_options = Convert.to_string(
        UI.QueryWidget(:ethtool_opts, :Value)
      )

      nil
    end


    # S/390 devices configuration dialog
    # @return dialog result
    def S390Dialog
      # S/390 dialog caption
      caption = _("S/390 Network Card Configuration")

      drvtype = DriverType(LanItems.type)

      helptext = ""
      contents = Empty()


      if Builtins.contains(["qeth", "hsi"], LanItems.type)
        # CHANIDS
        tmp_list = Builtins.splitstring(LanItems.qeth_chanids, " ")
        chanids_map = {
          "read"    => Ops.get(tmp_list, 0, ""),
          "write"   => Ops.get(tmp_list, 1, ""),
          "control" => Ops.get(tmp_list, 2, "")
        }
        contents = HBox(
          HSpacing(6),
          # Frame label
          Frame(
            _("S/390 Device Settings"),
            HBox(
              HSpacing(2),
              VBox(
                VSpacing(1),
                HBox(
                  # TextEntry label
                  InputField(
                    Id(:qeth_portname),
                    Opt(:hstretch),
                    _("&Port Name"),
                    LanItems.qeth_portname
                  ),
                  ComboBox(
                    Id(:qeth_portnumber),
                    _("Port Number"),
                    [Item(Id("0"), "0", true), Item(Id("1"), "1")]
                  )
                ),
                VSpacing(1),
                # TextEntry label
                InputField(
                  Id(:qeth_options),
                  Opt(:hstretch),
                  Label.Options,
                  LanItems.qeth_options
                ),
                VSpacing(1),
                # CheckBox label
                Left(CheckBox(Id(:ipa_takeover), _("&Enable IPA Takeover"))),
                VSpacing(1),
                # CheckBox label
                Left(
                  CheckBox(
                    Id(:qeth_layer2),
                    Opt(:notify),
                    _("Enable &Layer 2 Support")
                  )
                ),
                # TextEntry label
                InputField(
                  Id(:qeth_macaddress),
                  Opt(:hstretch),
                  _("Layer2 &MAC Address"),
                  LanItems.qeth_macaddress
                ),
                VSpacing(1),
                HBox(
                  InputField(
                    Id(:qeth_chan_read),
                    Opt(:hstretch),
                    _("Read Channel"),
                    Ops.get_string(chanids_map, "read", "")
                  ),
                  InputField(
                    Id(:qeth_chan_write),
                    Opt(:hstretch),
                    _("Write Channel"),
                    Ops.get_string(chanids_map, "write", "")
                  ),
                  InputField(
                    Id(:qeth_chan_control),
                    Opt(:hstretch),
                    _("Control Channel"),
                    Ops.get_string(chanids_map, "control", "")
                  )
                )
              ),
              HSpacing(2)
            )
          ),
          HSpacing(6)
        )
        # S/390 dialog help: QETH Port name
        helptext = _(
          "<p>Enter the <b>Port Name</b> for this interface (case-sensitive).</p>"
        ) +
          # S/390 dialog help: QETH Options
          _(
            "<p>Enter any additional <b>Options</b> for this interface (separated by spaces).</p>"
          ) +
          _(
            "<p>Select <b>Enable IPA Takeover</b> if IP address takeover should be enabled for this interface.</p>"
          ) +
          _(
            "<p>Select <b>Enable Layer 2 Support</b> if this card has been configured with layer 2 support.</p>"
          ) +
          _(
            "<p>Enter the <b>Layer 2 MAC Address</b> if this card has been configured with layer 2 support.</p>"
          )
      end

      if drvtype == "lcs"
        tmp_list = Builtins.splitstring(LanItems.qeth_chanids, " ")
        chanids_map = {
          "read"  => Ops.get(tmp_list, 0, ""),
          "write" => Ops.get(tmp_list, 1, "")
        }
        contents = HBox(
          HSpacing(6),
          # Frame label
          Frame(
            _("S/390 Device Settings"),
            HBox(
              HSpacing(2),
              VBox(
                VSpacing(1),
                # TextEntry label
                InputField(
                  Id(:chan_mode),
                  Opt(:hstretch),
                  _("&Port Number"),
                  LanItems.chan_mode
                ),
                VSpacing(1),
                # TextEntry label
                InputField(
                  Id(:lcs_timeout),
                  Opt(:hstretch),
                  _("&LANCMD Time-Out"),
                  LanItems.lcs_timeout
                ),
                VSpacing(1),
                HBox(
                  InputField(
                    Id(:qeth_chan_read),
                    Opt(:hstretch),
                    _("Read Channel"),
                    Ops.get_string(chanids_map, "read", "")
                  ),
                  InputField(
                    Id(:qeth_chan_write),
                    Opt(:hstretch),
                    _("Write Channel"),
                    Ops.get_string(chanids_map, "write", "")
                  )
                )
              ),
              HSpacing(2)
            )
          ),
          HSpacing(6)
        )
        # S/390 dialog help: LCS
        helptext = _("<p>Choose the <b>Port Number</b> for this interface.</p>") +
          _("<p>Specify the <b>LANCMD Time-Out</b> for this interface.</p>")
      end

      ctcitems = [
        # ComboBox item: CTC device protocol
        Item(Id("0"), _("Compatibility Mode")),
        # ComboBox item: CTC device protocol
        Item(Id("1"), _("Extended Mode")),
        # ComboBox item: CTC device protocol
        Item(Id("2"), _("CTC-Based tty (Linux to Linux Connections)")),
        # ComboBox item: CTC device protocol
        Item(Id("3"), _("Compatibility Mode with OS/390 and z/OS"))
      ]

      if drvtype == "ctc"
        tmp_list = Builtins.splitstring(LanItems.qeth_chanids, " ")
        chanids_map = {
          "read"  => Ops.get(tmp_list, 0, ""),
          "write" => Ops.get(tmp_list, 1, "")
        }
        contents = HBox(
          HSpacing(6),
          # Frame label
          Frame(
            _("S/390 Device Settings"),
            HBox(
              HSpacing(2),
              VBox(
                VSpacing(1),
                # TextEntry label
                ComboBox(Id(:chan_mode), _("&Protocol"), ctcitems),
                VSpacing(1),
                HBox(
                  InputField(
                    Id(:qeth_chan_read),
                    Opt(:hstretch),
                    _("Read Channel"),
                    Ops.get_string(chanids_map, "read", "")
                  ),
                  InputField(
                    Id(:qeth_chan_write),
                    Opt(:hstretch),
                    _("Write Channel"),
                    Ops.get_string(chanids_map, "write", "")
                  )
                )
              ),
              HSpacing(2)
            )
          ),
          HSpacing(6)
        )
        # S/390 dialog help: CTC
        helptext = _("<p>Choose the <b>Protocol</b> for this interface.</p>")
      end

      if drvtype == "iucv"
        contents = HBox(
          HSpacing(6),
          # Frame label
          Frame(
            _("S/390 Device Settings"),
            HBox(
              HSpacing(2),
              VBox(
                VSpacing(1),
                # TextEntry label, #42789
                InputField(
                  Id(:iucv_user),
                  Opt(:hstretch),
                  _("&Peer Name"),
                  LanItems.iucv_user
                ),
                VSpacing(1)
              ),
              HSpacing(2)
            )
          ),
          HSpacing(6)
        )
        # S/390 dialog help: IUCV, #42789
        helptext = _(
          "<p>Enter the name of the IUCV peer,\nfor example, the z/VM user name with which to connect (case-sensitive).</p>\n"
        )
      end

      Wizard.SetContentsButtons(
        caption,
        contents,
        helptext,
        Label.BackButton,
        Label.NextButton
      )

      if drvtype == "ctc"
        UI.ChangeWidget(Id(:chan_mode), :Value, LanItems.chan_mode)
      end

      if drvtype == "lcs"
        UI.ChangeWidget(Id(:chan_mode), :Value, LanItems.chan_mode)
        UI.ChangeWidget(Id(:lcs_timeout), :Value, LanItems.lcs_timeout)
      end

      if drvtype == "qeth"
        UI.ChangeWidget(Id(:ipa_takeover), :Value, LanItems.ipa_takeover)
        UI.ChangeWidget(Id(:qeth_layer2), :Value, LanItems.qeth_layer2)
        UI.ChangeWidget(
          Id(:qeth_macaddress),
          :ValidChars,
          ":0123456789abcdefABCDEF"
        )
      end

      case LanItems.type
        when "hsi"
          UI.SetFocus(Id(:qeth_options))
        when "qeth"
          UI.SetFocus(Id(:qeth_portname))
        when "iucv"
          UI.SetFocus(Id(:iucv_user))
        else
          UI.SetFocus(Id(:chan_mode))
      end

      ret = nil
      while true
        if drvtype == "qeth"
          mac_enabled = Convert.to_boolean(
            UI.QueryWidget(Id(:qeth_layer2), :Value)
          )
          UI.ChangeWidget(Id(:qeth_macaddress), :Enabled, mac_enabled)
        end

        ret = UI.UserInput

        if ret == :abort || ret == :cancel
          if ReallyAbort()
            break
          else
            next
          end
        elsif ret == :back
          break
        elsif ret == :next
          if LanItems.type == "iucv"
            # #176330, must be static
            LanItems.nm_name = Ops.add(
              "static-iucv-id-",
              Convert.to_string(UI.QueryWidget(Id(:iucv_user), :Value))
            )
            LanItems.device = Ops.add(
              "id-",
              Convert.to_string(UI.QueryWidget(Id(:iucv_user), :Value))
            )
            LanItems.iucv_user = Convert.to_string(
              UI.QueryWidget(Id(:iucv_user), :Value)
            )
          end

          if LanItems.type == "ctc"
            LanItems.chan_mode = Convert.to_string(
              UI.QueryWidget(Id(:chan_mode), :Value)
            )
          end
          if LanItems.type == "lcs"
            LanItems.lcs_timeout = Convert.to_string(
              UI.QueryWidget(Id(:lcs_timeout), :Value)
            )
            LanItems.chan_mode = Convert.to_string(
              UI.QueryWidget(Id(:chan_mode), :Value)
            )
          end
          if LanItems.type == "qeth" || LanItems.type == "hsi"
            LanItems.qeth_options = Convert.to_string(
              UI.QueryWidget(Id(:qeth_options), :Value)
            )
            LanItems.ipa_takeover = Convert.to_boolean(
              UI.QueryWidget(Id(:ipa_takeover), :Value)
            )
            LanItems.qeth_layer2 = Convert.to_boolean(
              UI.QueryWidget(Id(:qeth_layer2), :Value)
            )
            LanItems.qeth_macaddress = Convert.to_string(
              UI.QueryWidget(Id(:qeth_macaddress), :Value)
            )
            LanItems.qeth_portnumber = Convert.to_string(
              UI.QueryWidget(Id(:qeth_portnumber), :Value)
            )
            LanItems.qeth_portname = Convert.to_string(
              UI.QueryWidget(Id(:qeth_portname), :Value)
            )
          end
          read = Convert.to_string(UI.QueryWidget(Id(:qeth_chan_read), :Value))
          write = Convert.to_string(
            UI.QueryWidget(Id(:qeth_chan_write), :Value)
          )
          control = Convert.to_string(
            UI.QueryWidget(Id(:qeth_chan_control), :Value)
          )
          control = "" if control == nil
          LanItems.qeth_chanids = String.CutBlanks(
            Builtins.sformat("%1 %2 %3", read, write, control)
          )
          if !LanItems.createS390Device
            Popup.Error(
              _(
                "An error occurred while creating device.\nSee YaST log for details."
              )
            )
            ret = nil
            next
          end
          break
        elsif ret == :qeth_layer2
          next
        else
          Builtins.y2error("Unexpected return code: %1", ret)
          next
        end
      end

      deep_copy(ret)
    end

    # Manual network card configuration dialog
    # @return dialog result
    def HardwareDialog
      caption = _("Hardware Dialog")

      w = CWM.CreateWidgets(["HWDIALOG"], @widget_descr_hardware)
      contents = VBox(
        VStretch(),
        HBox(
          HStretch(),
          HSpacing(1),
          VBox(Ops.get_term(w, [0, "widget"]) { VSpacing(1) }),
          HSpacing(1),
          HStretch()
        ),
        VStretch()
      )

      help = CWM.MergeHelps(w)
      contents = CWM.PrepareDialog(contents, w)

      Wizard.OpenNextBackDialog
      Wizard.SetContents(caption, contents, initHelp, false, true)
      Wizard.SetAbortButton(:cancel, Label.CancelButton)
      ret = CWM.Run(
        w,
        {}
      )
      Wizard.CloseDialog
      deep_copy(ret)
    end
  end
end
