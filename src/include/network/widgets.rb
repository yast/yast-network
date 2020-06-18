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
      Yast.import "NetworkInterfaces"
      Yast.import "NetworkService"
      Yast.import "Lan"

      Yast.include include_target, "network/complex.rb"
    end

    # Validator for IP adresses, no_popup
    # @param key [String] the widget being validated
    # @param _event [Hash] the event being handled
    # @return whether valid
    def ValidateIP(key, _event)
      value = Convert.to_string(UI.QueryWidget(Id(key), :Value))
      return IP.Check(value) if value != ""

      true
    end

    # Initialize the NetworkManager widget
    # @param _key [String] id of the widget
    def ManagedInit(_key)
      items = []

      Y2Network::Backend.available.each do |backend|
        items << Item(
          Id(backend.name),
          # the user can control the network with the NetworkManager program
          backend.label,
          !!Lan.yast_config&.backend?(backend.id)
        )
      end

      items << Item(
        Id("disabled"),
        # used when no network service is active or to disable network service
        _("Network Services Disabled"),
        Lan.yast_config&.backend.nil?
      )

      UI.ChangeWidget(Id(:managed), :Items, items)

      nil
    end

    # Store the NetworkManager widget
    # @param _key [String] id of the widget
    # @param _event [Hash] the event being handled
    def ManagedStore(_key, _event)
      new_backend = UI.QueryWidget(Id(:managed), :Value)

      Lan.yast_config.backend = new_backend.to_sym

      if Lan.system_config.backend != Lan.yast_config.backend
        if Stage.normal && Lan.yast_config&.backend?(:network_manager)
          Popup.AnyMessage(
            _("Applet needed"),
            _(
              "NetworkManager is controlled by desktop applet\n" \
              "(KDE plasma widget and nm-applet for GNOME).\n" \
              "Be sure it's running and if not, start it manually."
            )
          )
        end
      end

      nil
    end

    def ManagedHandle(_key, _event)
      selected_service = UI.QueryWidget(Id(:managed), :Value)

      # Disable / enable all widgets which depends on network service
      # in the Managed dialog
      # See include/network/lan/dhcp.rb for referenced widgets
      [:clientid, :hostname, :no_defaultroute].each do |i|
        UI.ChangeWidget(Id(i), :Enabled, selected_service == "wicked")
      end

      nil
    end

    def managed_widget
      {
        "widget"        => :custom,
        "custom_widget" => Frame(
          _("General Network Settings"),
          Left(
            ComboBox(
              Id(:managed),
              Opt(:hstretch, :notify),
              _("Network Setup Method"),
              []
            )
          )
        ),
        "opt"           => [],
        "help"          => @help["managed"] || "",
        "init"          => fun_ref(method(:ManagedInit), "void (string)"),
        "handle"        => fun_ref(method(:ManagedHandle), "symbol (string, map)"),
        "store"         => fun_ref(method(:ManagedStore), "void (string, map)")
      }
    end

    def initIPv6(_key)
      UI.ChangeWidget(Id(:ipv6), :Value, Lan.ipv6 ? true : false)

      nil
    end

    def handleIPv6(_key, event)
      if Ops.get_string(event, "EventReason", "") == "ValueChanged"
        Lan.SetIPv6(Convert.to_boolean(UI.QueryWidget(Id(:ipv6), :Value)))
      end
      nil
    end

    def storeIPv6(_key, _event)
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
  end
end
