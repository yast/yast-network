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
# File:  include/network/lan/dialogs.ycp
# Package:  Network configuration
# Summary:  Summary, overview and IO dialogs for network cards config
# Authors:  Michal Svec <msvec@suse.cz>
#

require "y2network/interface_config_builder"
require "y2network/sequences/interface"
require "y2network/widgets/interfaces_table"
require "y2network/widgets/interface_description"
require "y2network/widgets/add_interface"
require "y2network/widgets/edit_interface"
require "y2network/widgets/delete_interface"

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
      Yast.import "Wizard"
      Yast.import "Popup"
      Yast.import "Label"
      Yast.import "Package"
      Yast.import "TablePopup"
      Yast.import "CWMTab"
      Yast.import "Stage"
      Yast.import "LanItems"
      Yast.import "Systemd"

      Yast.include include_target, "network/routines.rb"
      Yast.include include_target, "network/lan/help.rb"
      Yast.include include_target, "network/services/routing.rb"
      Yast.include include_target, "network/services/dns.rb"
      Yast.include include_target, "network/lan/dhcp.rb"
      Yast.include include_target, "network/lan/s390.rb"
      Yast.include include_target, "network/widgets.rb"

      @shown = false
    end

    def wd
      return @wd if @wd

      @wd = {
        "MANAGED"                       => managed_widget,
        "IPV6"                          => ipv6_widget,
        interfaces_table.widget_id      => interfaces_table.cwm_definition,
        interface_description.widget_id => interface_description.cwm_definition,
        add_interface.widget_id         => add_interface.cwm_definition,
        edit_interface.widget_id        => edit_interface.cwm_definition,
        delete_interface.widget_id      => delete_interface.cwm_definition
      }

      @wd = Convert.convert(
        Builtins.union(@wd, @widget_descr_dns),
        from: "map",
        to:   "map <string, map <string, any>>"
      )
      @wd = Convert.convert(
        Builtins.union(@wd, widgets), # routing widgets
        from: "map",
        to:   "map <string, map <string, any>>"
      )
      @wd = Convert.convert(
        Builtins.union(@wd, @widget_descr_dhclient),
        from: "map",
        to:   "map <string, map <string, any>>"
      )
    end

    def tabs_descr
      return @tabs_descr if @tabs_descr

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
          "contents"     => VBox(
            interfaces_table.widget_id,
            interface_description.widget_id,
            Left(
              HBox(
                add_interface.widget_id, edit_interface.widget_id, delete_interface.widget_id
              )
            )
          ),
          "widget_names" => [
            interfaces_table.widget_id, interface_description.widget_id, add_interface.widget_id,
            edit_interface.widget_id, delete_interface.widget_id
          ]
        }
      }
      @tabs_descr = Builtins.union(@tabs_descr, route_td)
      @tabs_descr = Builtins.union(@tabs_descr, @dns_td)
    end

    def interfaces_table
      @interfaces_table ||= Y2Network::Widgets::InterfacesTable.new(interface_description)
    end

    def interface_description
      @interface_description ||= Y2Network::Widgets::InterfaceDescription.new
    end

    def add_interface
      @add_interface ||= Y2Network::Widgets::AddInterface.new
    end

    def edit_interface
      @edit_interface ||= Y2Network::Widgets::EditInterface.new(interfaces_table)
    end

    def delete_interface
      @delete_interface ||= Y2Network::Widgets::DeleteInterface.new(interfaces_table)
    end

    # Commit changes to internal structures
    # @return always `next
    def Commit(builder:)
      # 1) update NetworkInterfaces with corresponding devmap
      # FIXME: new item in NetworkInterfaces was created from handleOverview by
      # calling Lan.Add and named in HardwareDialog via NetworkInterfaces.Name=
      #  - all that stuff can (should) be moved here to have it isolated at one place
      #  and later moved to Interface object
      LanItems.Commit(builder)

      :next
    end

    # Read settings dialog
    # @return `abort if aborted and `next otherwise
    def ReadDialog
      Wizard.RestoreHelp(Ops.get_string(@help, "read", ""))
      Lan.AbortFunction = -> { PollAbort() }
      ret = Lan.Read(:cache)
      # Currently just a smoketest for new config storage -
      # something what should replace Lan module in the bright future
      # TODO: find a suitable place for this config storage
      Y2Network::Config.from(:sysconfig)

      if Lan.HaveXenBridge
        if !Popup.ContinueCancel(
          Builtins.sformat(
            # continue-cancel popup, #178848
            # %1 is a (long) path to a README file
            _(
              "A Xen network bridge was detected.\n" \
                "Due to the renaming of network interfaces by the bridge script,\n" \
                "network interfaces should not be configured or restarted.\n" \
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

      Wizard.RestoreHelp(Ops.get_string(@help, "write", ""))
      Lan.AbortFunction = -> { PollAbort() && ReallyAbort() }
      ret = Lan.Write
      ret ? :next : :abort
    end

    # Returns true if the device can be used (means handled as normal linux device)
    # or false otherwise (it is used mainly at s390 based systems where a special
    # handling is needed to run linux device emulation)
    def DeviceReady(devname)
      !Arch.s390 || s390_DriverLoaded(devname)
    end

    def ManagedDialog
      contents = VBox(HSquash(VBox("MANAGED", VSpacing(0.5), "IPV6")))

      functions = { abort: fun_ref(method(:ReallyAbort), "boolean ()") }

      ret = CWM.ShowAndRun(
        "widget_descr"       => wd,
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
      )

      # #148485: always show the device overview
      ret
    end

    # Evaluates if user should be asked again according dialogs result value
    #
    # it is basically useful if user aborts dialog and he has done some
    # changes already. Calling this function may results in confirmation
    # popup.
    def input_done?(ret)
      return true if ret != :abort

      return Popup.ConfirmAbort(:painless) if Stage.initial

      return ReallyAbort() if LanItems.GetModified

      true
    end

    def MainDialog(init_tab)
      caption = _("Network Settings")
      widget_descr = {
        "tab" => CWMTab.CreateWidget(
          "tab_order"    => if Systemd.Running
                              ["global", "overview", "resolv", "route"]
                            else
                              ["overview", "resolv", "route"]
                            end,
          "tabs"         => tabs_descr,
          "widget_descr" => wd,
          "initial_tab"  => Stage.normal ? init_tab : "overview",
          "tab_help"     => ""
        )
      }
      contents = VBox("tab")

      w = CWM.CreateWidgets(
        ["tab"],
        Convert.convert(
          widget_descr,
          from: "map",
          to:   "map <string, map <string, any>>"
        )
      )

      help = CWM.MergeHelps(w)
      contents = CWM.PrepareDialog(contents, w)
      running_installer = Mode.installation || Mode.update

      Wizard.SetContentsButtons(
        caption,
        contents,
        help,
        Label.BackButton,
        running_installer ? Label.NextButton : Label.OKButton
      )

      if running_installer
        Wizard.SetAbortButton(:abort, Label.AbortButton)
      else
        Wizard.SetAbortButton(:abort, Label.CancelButton)
        Wizard.HideBackButton
      end

      ret = nil
      loop do
        ret = CWM.Run(w, {})
        break if input_done?(ret)
      end

      ret
    end
  end
end
