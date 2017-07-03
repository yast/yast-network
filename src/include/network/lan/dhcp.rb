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
# File:	include/network/lan/dhcp.ycp
# Package:	Network configuration
# Summary:	Network card adresss configuration dialogs
# Authors:	Michal Svec <msvec@suse.cz>
#
module Yast
  module NetworkLanDhcpInclude
    def initialize_network_lan_dhcp(include_target)
      Yast.import "UI"

      textdomain "network"

      Yast.import "NetworkConfig"

      Yast.include include_target, "network/routines.rb"
      Yast.include include_target, "network/lan/help.rb"

      # Details dialog contents
      @contents =
        # Frame label
        Frame(
          _("DHCP Client Options"),
          VBox(
            Left(
              InputField(
                Id(:clientid),
                Opt(:hstretch),
                _("DHCP Client &Identifier")
              )
            ),
            VSpacing(0.49),
            # TextEntry label
            Left(
              InputField(Id(:hostname), Opt(:hstretch), _("&Hostname to Send"))
            ),
            VSpacing(0.49),
            Left(
              HBox(
                CheckBox(
                  Id(:no_defaultroute),
                  _("Change Default Route via DHCP")
                )
              )
            )
          )
        )

      @widget_descr_dhclient = {
        "DHCLIENT_OPTIONS" => {
          "widget"        => :custom,
          "custom_widget" => @contents,
          "help"          => Ops.get_string(@help, "dhclient_help", ""),
          "init"          => fun_ref(
            method(:initDhclientOptions),
            "void (string)"
          ),
          "store"         => fun_ref(
            method(:storeDhclientOptions),
            "void (string, map)"
          )
        }
      }
    end

    def initDhclientOptions(_key)
      UI.ChangeWidget(
        Id(:clientid),
        :Value,
        Ops.get_string(NetworkConfig.DHCP, "DHCLIENT_CLIENT_ID", "")
      )
      UI.ChangeWidget(
        Id(:hostname),
        :Value,
        Ops.get_string(NetworkConfig.DHCP, "DHCLIENT_HOSTNAME_OPTION", "")
      )
      UI.ChangeWidget(
        Id(:no_defaultroute),
        :Value,
        Ops.get_boolean(NetworkConfig.DHCP, "DHCLIENT_SET_DEFAULT_ROUTE", true)
      )

      disable_unconfigureable_items(
        [:clientid, :hostname, :no_defaultroute],
        false
      )

      nil
    end

    def storeDhclientOptions(_key, _event)
      Ops.set(
        NetworkConfig.DHCP,
        "DHCLIENT_SET_DEFAULT_ROUTE",
        UI.QueryWidget(Id(:no_defaultroute), :Value) == true
      )
      Ops.set(
        NetworkConfig.DHCP,
        "DHCLIENT_CLIENT_ID",
        UI.QueryWidget(Id(:clientid), :Value)
      )
      Ops.set(
        NetworkConfig.DHCP,
        "DHCLIENT_HOSTNAME_OPTION",
        UI.QueryWidget(Id(:hostname), :Value)
      )

      nil
    end
  end
end
