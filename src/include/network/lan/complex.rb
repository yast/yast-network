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
      Yast.import "Systemd"
      Yast.import "GetInstArgs"

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
      return @edit_interface if @edit_interface

      @edit_interface = Y2Network::Widgets::EditInterface.new(interfaces_table)
      interfaces_table.add_handler(@edit_interface)
      @edit_interface
    end

    def delete_interface
      return @delete_interface if @delete_interface

      @delete_interface = Y2Network::Widgets::DeleteInterface.new(interfaces_table)
      interfaces_table.add_handler(@delete_interface)
      @delete_interface
    end

    # Commit changes to internal structures
    # @return always `next
    def Commit(builder:)
      builder.save

      :next
    end

    # Read settings dialog
    # @return `abort if aborted and `next otherwise
    def ReadDialog
      Wizard.RestoreHelp(Ops.get_string(@help, "read", ""))
      Lan.AbortFunction = -> { PollAbort() }
      ret = Lan.Read(:cache)

      if Lan.HaveXenBridge && !Popup.ContinueCancel(
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

      bonding_fix.run if ret && bonding_fix.needs_to_be_run?

      ret ? :next : :abort
    end

    def bonding_fix
      require "y2network/dialogs/bonding_fix"
      @bonding_fix ||= Y2Network::Dialogs::BondingFix.new(Lan.yast_config)
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

    # Evaluates if user should be asked again according dialogs result value
    #
    # it is basically useful if user aborts dialog and he has done some
    # changes already. Calling this function may results in confirmation
    # popup.
    def input_done?(ret)
      return true if ret != :abort

      return Popup.ConfirmAbort(:painless) if Stage.initial

      return ReallyAbort() if Lan.yast_config != Lan.system_config

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

      Wizard.SetContentsButtons(
        caption,
        contents,
        help,
        Label.BackButton,
        next_button_label
      )

      Wizard.SetAbortButton(:abort, abort_button_label)
      Wizard.HideAbortButton if hide_abort_button?
      Wizard.HideBackButton unless running_installer?

      ret = nil

      loop do
        ret = CWM.Run(w, {})
        break if input_done?(ret)
      end

      ret
    end

    # The label for the next/ok button
    #
    # @return [String]
    def next_button_label
      running_installer? ? Label.NextButton : Label.OKButton
    end

    # The label for the abort/quit button
    #
    # @return [String]
    def abort_button_label
      running_installer? ? Label.AbortButton : Label.CancelButton
    end

    # Whether abort button should be hide
    #
    # @return [Boolean] true if running during installation and disable_abort_button inst argument
    # is present and true; false otherwise
    def hide_abort_button?
      return false unless running_installer?

      GetInstArgs.argmap["hide_abort_button"] == true
    end

    # Whether running during installation
    #
    # @return [Boolean] true when running during installation, false otherwise
    def running_installer?
      Mode.installation || Mode.update
    end
  end
end
