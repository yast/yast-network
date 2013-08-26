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
# File:	include/network/lan/dialogs.ycp
# Package:	Network configuration
# Summary:	Summary, overview and IO dialogs for network cards config
# Authors:	Michal Svec <msvec@suse.cz>
#
module Yast
  module NetworkLanComplexInclude
    def initialize_network_lan_complex(include_target)
      Yast.import "UI"

      textdomain "network"

      Yast.import "CWM"

      Yast.import "Lan"
      Yast.import "DNS"
      Yast.import "Mode"
      Yast.import "NetworkConfig"
      Yast.import "NetworkService"
      Yast.import "Routing"
      Yast.import "Wizard"
      Yast.import "Popup"
      Yast.import "Label"
      Yast.import "Package"
      Yast.import "TablePopup"
      Yast.import "CWMTab"
      Yast.import "Stage"
      Yast.import "LanItems"

      Yast.include include_target, "network/routines.rb"
      Yast.include include_target, "network/summary.rb"
      Yast.include include_target, "network/lan/help.rb"
      Yast.include include_target, "network/services/routing.rb"
      Yast.include include_target, "network/services/dns.rb"
      Yast.include include_target, "network/lan/dhcp.rb"
      Yast.include include_target, "network/lan/s390.rb"

      @shown = false

      @wd = {
        "MANAGED"  => {
          "widget" => :radio_buttons,
          # radio button group label, method of setup
          "label"  => _(
            "Network Setup Method"
          ),
          "items"  => [
            # radio button label
            # the user can control the network with the NetworkManager
            # program
            ["managed", _("&User Controlled with NetworkManager")],
            # radio button label
            # ifup is a program name
            ["ifup", _("&Traditional Method with ifup")]
          ],
          "opt"    => [],
          "help"   => Ops.get_string(@help, "managed", ""),
          "init"   => fun_ref(method(:ManagedInit), "void (string)"),
          "store"  => fun_ref(method(:ManagedStore), "void (string, map)")
        },
        "IPV6"     => {
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
        },
        "OVERVIEW" => {
          "widget"        => :custom,
          "custom_widget" => VBox(
            VWeight(
              2,
              Table(
                Id(:_hw_items),
                Opt(:notify, :immediate),
                Header(_("Name"), _("IP Address"), _("Device"), _("Note"))
              )
            ),
            VWeight(1, RichText(Id(:_hw_sum), "")),
            HBox(
              PushButton(Id(:add), Label.AddButton),
              PushButton(Id(:edit), Label.EditButton),
              PushButton(Id(:delete), Label.DeleteButton),
              HStretch()
            )
          ),
          "init"          => fun_ref(method(:initOverview), "void (string)"),
          "handle"        => fun_ref(
            method(:handleOverview),
            "symbol (string, map)"
          ),
          #	    "store" : storeOverview,
          "help"          => Ops.get_string(
            @help,
            "overview",
            ""
          )
        }
      }

      @wd = Convert.convert(
        Builtins.union(@wd, @widget_descr_dns),
        :from => "map",
        :to   => "map <string, map <string, any>>"
      )
      @wd = Convert.convert(
        Builtins.union(@wd, @wd_routing),
        :from => "map",
        :to   => "map <string, map <string, any>>"
      )
      @wd = Convert.convert(
        Builtins.union(@wd, @widget_descr_dhclient),
        :from => "map",
        :to   => "map <string, map <string, any>>"
      )


      @tabs_descr = {
        "global"   => {
          "header"       => _("Global Options"),
          "contents"     => VBox(
            MarginBox(1, 0.49, "MANAGED"),
            MarginBox(1, 0.49, "IPV6"),
            MarginBox(1, 0.49, "DHCLIENT_OPTIONS"),
            VStretch()
          ),
          "widget_names" => ["MANAGED", "IPV6", "DHCLIENT_OPTIONS"]
        },
        "overview" => {
          "header"       => _("Overview"),
          "contents"     => VBox("OVERVIEW"),
          "widget_names" => ["OVERVIEW"]
        }
      }
      @tabs_descr = Builtins.union(@tabs_descr, @route_td)
      @tabs_descr = Builtins.union(@tabs_descr, @dns_td)
    end

    # Commit changes to internal structures
    # @return always `next
    def Commit
      LanItems.Commit
      :next
    end

    # Display finished popup
    # @return dialog result
    # define symbol FinishDialog() ``{
    #     return FinishPopup(Modified(), "lan", "", "mail", ["permanent"]);
    # }

    # Read settings dialog
    # @return `abort if aborted and `next otherwise
    def ReadDialog
      Wizard.RestoreHelp(Ops.get_string(@help, "read", ""))
      Lan.AbortFunction = lambda { PollAbort() }
      ret = Lan.Read(:cache)

      if Lan.HaveXenBridge
        if !Popup.ContinueCancel(
            Builtins.sformat(
              # continue-cancel popup, #178848
              # %1 is a (long) path to a README file
              _(
                "A Xen network bridge was detected.\n" +
                  "Due to the renaming of network interfaces by the bridge script,\n" +
                  "network interfaces should not be configured or restarted.\n" +
                  "See %1 for details."
              ),
              "/usr/share/doc/packages/xen/README.SuSE"
            )
          )
          ret = false
        end
      end

      ret ? :next : :abort
    end

    # Write settings dialog
    # @return `abort if aborted and `next otherwise
    def WriteDialog
      return :next if !Lan.Modified

      LanItems.SetModified
      Wizard.RestoreHelp(Ops.get_string(@help, "write", ""))
      Lan.AbortFunction = lambda { PollAbort() && ReallyAbort() }
      ret = Lan.Write
      ret ? :next : :abort
    end

    def AddInterface
      Lan.Add
      LanItems.operation = :add
      LanItems.SelectHWMap(Ops.get_map(LanItems.getCurrentItem, "hwinfo", {}))
      Ops.set(
        LanItems.Items,
        [LanItems.current, "ifcfg"],
        Ops.get_string(LanItems.getCurrentItem, ["hwinfo", "dev_name"], "")
      )
      Ops.set(LanItems.Items, [LanItems.current, "commited"], false)
      LanItems.operation = :edit
      fw = ""
      if LanItems.needFirmwareCurrentItem
        fw = LanItems.GetFirmwareForCurrentItem
        if fw != ""
          if !Package.Installed(fw) && !Package.Available(fw)
            Popup.Message(
              Builtins.sformat(
                _(
                  "Firmware is needed. Install it from \n" +
                    "the add-on CD.\n" +
                    "First add the add-on CD to your YaST software repositories then return \n" +
                    "to this configuration dialog.\n"
                )
              )
            )
            return false
          elsif !Builtins.contains(LanItems.Requires, fw)
            LanItems.Requires = Builtins.add(LanItems.Requires, fw)
          end
        else
          return Popup.ContinueCancel(
            _(
              "The device needs a firmware to function properly. Usually, it can be\n" +
                "downloaded from your driver vendor's Web page. \n" +
                "If you have already downloaded and installed the firmware, click\n" +
                "<b>Continue</b> to configure the device. Otherwise click <b>Cancel</b> and\n" +
                "return to this dialog once you have installed the firmware.\n"
            )
          )
        end
      end

      # this is one of 3 places to install packages :-(
      # - kernel modules (InstallKernel): before loaded
      # - smpppd & qinternet: before net start
      # - wlan firmware: here, just because it is copied from modems
      #   #45960
      if LanItems.Requires != [] && LanItems.Requires != nil
        return false if PackagesInstall(LanItems.Requires) != :next
        if fw == "b43-fwcutter"
          if Popup.ContinueCancelHeadline(
              _("Installing firmware"),
              _(
                "For successful firmware installation, the 'install_bcm43xx_firmware' script needs to be executed. Execute it now?"
              )
            )
            command = Convert.convert(
              SCR.Execute(
                path(".target.bash_output"),
                "/usr/sbin/install_bcm43xx_firmware"
              ),
              :from => "any",
              :to   => "map <string, any>"
            )
            if Ops.get_integer(command, "exit", -1) != 0
              Popup.ErrorDetails(
                _("An error occurred during firmware installation."),
                Ops.get_string(command, "stderr", "")
              )
            else
              Popup.Message("bcm43xx_firmware installed successfully")
            end
          end
        end
      end
      #    TODO: Refresh hwinfo in LanItems
      true
    end

    # Returns true if the device can be used (means handled as normal linux device)
    # or false otherwise (it is used mainly at s390 based systems where a special
    # handling is needed to run linux device emulation)
    def DeviceReady(devname)
      !Arch.s390 || s390_DriverLoaded(devname)
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

    # Initialize the NetworkManager widget
    # @param [String] key id of the widget
    def ManagedInit(key)
      value = NetworkService.IsManaged ? "managed" : "ifup"
      UI.ChangeWidget(Id(key), :CurrentButton, value)

      nil
    end

    # Store the NetworkManager widget
    # @param [String] key	id of the widget
    # @param [Hash] event	the event being handled
    def ManagedStore(key, event)
      event = deep_copy(event)
      value_g = Convert.to_string(UI.QueryWidget(Id(key), :CurrentButton))
      value = value_g == "managed"
      if NetworkService.IsManaged != value
        LanItems.SetModified
        if value && Stage.normal
          Popup.AnyMessage(
            _("Applet needed"),
            _(
              "NetworkManager is controlled by desktop applet\n" +
                "(KDE plasma widget and nm-applet for GNOME).\n" +
                "Be sure it's running and if not, start it manually."
            )
          )
        end
      end
      NetworkService.SetManaged(value)

      nil
    end

    def enableDisableButtons
      LanItems.current = Convert.to_integer(
        UI.QueryWidget(Id(:_hw_items), :CurrentItem)
      )

      UI.ChangeWidget(:_hw_sum, :Value, LanItems.GetItemDescription)
      if !LanItems.IsCurrentConfigured # unconfigured
        UI.ChangeWidget(Id(:delete), :Enabled, false)
      else
        UI.ChangeWidget(Id(:delete), :Enabled, true)
      end

      UI.ChangeWidget(Id(:edit), :Enabled, LanItems.enableCurrentEditButton)

      if !Mode.config && Lan.HaveXenBridge # #196479
        # #178848
        Builtins.foreach([:add, :edit, :delete]) do |b|
          UI.ChangeWidget(Id(b), :Enabled, false)
        end
      end

      nil
    end

    # Automatically configures bonding slaves when user enslaves them into a master bond device.
    def UpdateBondingSlaves
      current = LanItems.current

      Builtins.foreach(Lan.bond_autoconf_slaves) do |dev|
        if LanItems.FindAndSelect(dev)
          LanItems.SetItem
        else
          dev_index = LanItems.FindDeviceIndex(dev)
          if Ops.less_than(dev_index, 0)
            Builtins.y2error(
              "initOverview: invalid bond slave device name %1",
              dev
            )
            next
          end
          LanItems.current = dev_index

          AddInterface()

          # clear defaults, some defaults are invalid for bonding slaves and can cause troubles
          # in related sysconfig scripts or makes no sence for bonding slaves (e.g. ip configuration).
          LanItems.netmask = ""
        end
        LanItems.startmode = "hotplug"
        LanItems.bootproto = "none"
        # if particular bond slave uses mac based persistency, overwrite to bus id based one. Don't touch otherwise.
        LanItems.ReplaceItemUdev(
          "ATTR{address}",
          "KERNELS",
          Ops.get_string(LanItems.getCurrentItem, ["hwinfo", "busid"], "")
        )
        LanItems.Commit
      end

      LanItems.current = current

      nil
    end

    # Automatically updates interfaces configuration according users input.
    #
    # Perform automatic configuration based on user input. E.g. when an interface is inserted
    # into bond device and persistence based on bus id is required, then some configuration changes
    # are required in ifcfg and udev. It used to be needed to do it by hand before.
    def AutoUpdateOverview
      # TODO: allow disabling. E.g. iff bus id based persistency is not requested.
      UpdateBondingSlaves()

      nil
    end

    def initOverview(key)
      # search for automatic updates
      AutoUpdateOverview()

      # update table with device description
      term_items = Builtins.maplist(
        Convert.convert(
          LanItems.Overview,
          :from => "list",
          :to   => "list <map <string, any>>"
        )
      ) do |i|
        t = Item(Id(Ops.get_integer(i, "id", -1)))
        Builtins.foreach(Ops.get_list(i, "table_descr", [])) do |l|
          t = Builtins.add(t, l)
        end
        deep_copy(t)
      end
      UI.ChangeWidget(Id(:_hw_items), :Items, term_items)

      if !@shown
        disableItemsIfNM([:_hw_items, :_hw_sum, :add, :edit, :delete], true)
        @shown = true
      else
        enableDisableButtons
      end

      Builtins.y2milestone("LanItems %1", LanItems.Items)

      nil
    end

    def handleOverview(key, event)
      event = deep_copy(event)
      if !disableItemsIfNM([:_hw_items, :_hw_sum, :add, :edit, :delete], false)
        enableDisableButtons
      end
      UI.ChangeWidget(:_hw_sum, :Value, LanItems.GetItemDescription)

      if Ops.get_string(event, "EventReason", "") == "Activated"
        case Ops.get_symbol(event, "ID")
          when :add
            LanItems.AddNew
            Lan.Add
            return :add
          when :edit
            if LanItems.IsCurrentConfigured
              LanItems.SetItem

              if LanItems.startmode == "managed"
                # Continue-Cancel popup
                if !Popup.ContinueCancel(
                    _(
                      "The interface is currently set to be managed\n" +
                        "by the NetworkManager applet.\n" +
                        "\n" +
                        "If you edit the settings for this interface here,\n" +
                        "the interface will no longer be managed by NetworkManager.\n"
                    )
                  )
                  # y2r: cannot break from middle of switch
                  # but in this function return will do
                  return nil # means cancel
                end

                # TODO move the defaults to GetDefaultsForHW
                LanItems.startmode = "ifplugd"
              end
            else
              if !AddInterface()
                Builtins.y2error("handleOverview: AddInterface failed.")
                # y2r: cannot break from middle of switch
                # but in this function return will do
                return nil
              end

              if !DeviceReady(
                  Ops.get_string(
                    LanItems.getCurrentItem,
                    ["hwinfo", "dev_name"],
                    ""
                  )
                )
                return :init_s390
              end
            end

            return :edit
          when :delete
            @pop = Builtins.sformat(
              _(
                "All additional addresses belonging to the interface %1\n" +
                  "will be deleted as well.\n" +
                  "\n" +
                  "Really continue?\n"
              ),
              Ops.get_string(LanItems.getCurrentItem, "ifcfg", "")
            )
            if LanItems.InterfaceHasAliases &&
                Popup.YesNoHeadline(Label.WarningMsg, @pop) != true
              # y2r: cannot break from middle of switch
              # but in this function return will do
              return nil
            end

            # warn user when device to delete has STARTMODE=nfsroot (bnc#433867)
            if NetworkInterfaces.GetValue(
                Ops.get_string(LanItems.getCurrentItem, "ifcfg", ""),
                "STARTMODE"
              ) == "nfsroot"
              if !Popup.YesNoHeadline(
                  Label.WarningMsg,
                  _("Device you select has STARTMODE=nfsroot. Really delete?")
                )
                # y2r: cannot break from middle of switch
                # but in this function return will do
                return nil
              end
            end

            LanItems.DeleteItem
            initOverview("")
        end
      end
      if Builtins.size(LanItems.Items) == 0
        UI.ChangeWidget(:_hw_sum, :Value, "")
        UI.ChangeWidget(Id(:edit), :Enabled, false)
        UI.ChangeWidget(Id(:delete), :Enabled, false)
        return nil
      end

      nil
    end

    def ManagedDialog
      widget_descr = Builtins.union(
        Ops.get(@wd, "MANAGED", {}),
        Ops.get(@wd, "IPV6", {})
      )
      contents = VBox(HSquash(VBox("MANAGED", VSpacing(0.5), "IPV6")))

      functions = { :abort => fun_ref(method(:ReallyAbort), "boolean ()") }

      ret = CWM.ShowAndRun(
        {
          "widget_descr"       => @wd,
          "contents"           => contents,
          # Network setup method dialog caption
          "caption"            => _(
            "Network Setup Method"
          ),
          "back_button"        => Label.BackButton,
          "abort_button"       => Label.CancelButton,
          "next_button"        => Label.OKButton,
          # #54027
          "disable_buttons"    => ["back_button"],
          "fallback_functions" => functions
        }
      )

      # #148485: always show the device overview
      ret = :managed if false && ret == :next && NetworkService.IsManaged
      ret
    end

    def MainDialog(init_tab)
      caption = _("Network Settings")
      widget_descr = {
        "tab" => CWMTab.CreateWidget(
          {
            "tab_order"    => Stage.normal ?
              ["global", "overview", "resolv", "route"] :
              ["overview", "resolv", "route"],
            "tabs"         => @tabs_descr,
            "widget_descr" => @wd,
            "initial_tab"  => Stage.normal ? init_tab : "overview",
            "tab_help"     => ""
          }
        )
      }
      contents = VBox("tab")

      w = CWM.CreateWidgets(
        ["tab"],
        Convert.convert(
          widget_descr,
          :from => "map",
          :to   => "map <string, map <string, any>>"
        )
      )
      help = CWM.MergeHelps(w)
      contents = CWM.PrepareDialog(contents, w)

      Wizard.SetContentsButtons(
        caption,
        contents,
        help,
        Label.BackButton,
        Label.OKButton
      )
      Wizard.SetNextButton(:next, Label.OKButton)
      Wizard.SetAbortButton(:abort, Label.CancelButton)
      Wizard.HideBackButton

      ret = nil
      while true
        ret = CWM.Run(w, {})
        if ret == :abort
          next if LanItems.modified && !ReallyAbort()
          return ret
        end
        return ret
      end

      nil
    end
  end
end
