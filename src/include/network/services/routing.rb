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
# File:	include/network/services/routing.ycp
# Package:	Network configuration
# Summary:	Routing configuration dialogs
# Authors:	Michal Svec <msvec@suse.cz>
#
#
# Routing configuration dialogs
module Yast
  module NetworkServicesRoutingInclude
    def initialize_network_services_routing(include_target)
      Yast.import "UI"

      textdomain "network"

      Yast.import "IP"
      Yast.import "Label"
      Yast.import "Netmask"
      Yast.import "Popup"
      Yast.import "Routing"
      Yast.import "Wizard"
      Yast.import "Lan"
      Yast.import "CWM"
      Yast.import "CWMTab"
      Yast.import "NetworkService"

      Yast.include include_target, "network/lan/help.rb"
      Yast.include include_target, "network/routines.rb"

      @r_items = []
      @defgw = ""
      @defgwdev = ""

      @defgw6 = ""
      @defgwdev6 = ""
      @wd_routing = {
        "ROUTING" => {
          "widget"            => :custom,
          "custom_widget"     => HBox(
            HSpacing(5),
            VBox(
              VStretch(),
              # ComboBox label
              HBox(
                InputField(Id(:gw), Opt(:hstretch), _("Default IPv4 &Gateway")),
                ComboBox(Id(:gw4dev), Opt(:editable), _("Device"), [])
              ),
              HBox(
                InputField(Id(:gw6), Opt(:hstretch), _("Default IPv6 &Gateway")),
                ComboBox(Id(:gw6dev), Opt(:editable), _("Device"), [])
              ),
              VSpacing(1),
              # Frame label
              Frame(
                _("Routing Table"),
                VBox(
                  # CheckBox label
                  Table(
                    Id(:table),
                    Opt(:notify),
                    Header(
                      # Table header 1/4
                      _("Destination"),
                      # Table header 2/4
                      _("Gateway"),
                      # Table header 3/4
                      _("Genmask"),
                      # Table header 4/4
                      _("Device"),
                      # Table header 5/4
                      # FIXME
                      Builtins.deletechars(Label.Options, "&")
                    ),
                    []
                  ),
                  # PushButton label
                  HBox(
                    PushButton(Id(:add), _("Ad&d")),
                    # PushButton label
                    PushButton(Id(:edit), _("&Edit")),
                    # PushButton label
                    PushButton(Id(:delete), _("De&lete"))
                  )
                )
              ),
              VSpacing(1),
              # CheckBox label
              Left(CheckBox(Id(:forward_v4), _("Enable &IPv4 Forwarding"))),
              Left(CheckBox(Id(:forward_v6), _("Enable I&Pv6 Forwarding"))),
              VStretch()
            ),
            HSpacing(5)
          ),
          "init"              => fun_ref(method(:initRouting), "void (string)"),
          "handle"            => fun_ref(
            method(:handleRouting),
            "symbol (string, map)"
          ),
          "validate_type"     => :function,
          "validate_function" => fun_ref(
            method(:validateRouting),
            "boolean (string, map)"
          ),
          "store"             => fun_ref(
            method(:storeRouting),
            "void (string, map)"
          ),
          "help"              => Ops.get_string(@help, "routing", "")
        }
      }

      @route_td = {
        "route" => {
          "header"       => _("Routing"),
          "contents"     => VBox("ROUTING"),
          "widget_names" => ["ROUTING"]
        }
      }
    end

    # Route edit dialog
    # @param [Fixnum] id id of the edited route
    # @param [Yast::Term] entry edited entry
    # @param [Array] devs available devices
    # @return route or nil, if canceled
    def RoutingEditDialog(id, entry, devs)
      entry = deep_copy(entry)
      devs = deep_copy(devs)

      UI.OpenDialog(
        Opt(:decorated),
        MinWidth(60,
          VBox(
            HSpacing(1),
            VBox(
              HBox(
                HWeight(70,
                  InputField(
                    Id(:destination),
                    Opt(:hstretch),
                    _("&Destination"),
                    Ops.get_string(entry, 1, "")
                  )
                ),
                HSpacing(1),
                HWeight(30,
                  InputField(
                    Id(:genmask),
                    Opt(:hstretch),
                    _("Ge&nmask"),
                    Ops.get_string(entry, 3, "-")
                  )
                )
              ),
              HBox(
                HWeight(70,
                  InputField(
                    Id(:gateway),
                    Opt(:hstretch),
                    _("&Gateway"),
                    Ops.get_string(entry, 2, "-")
                  )
                ),
                HSpacing(1),
                HWeight(30,
                  ComboBox(
                    Id(:device),
                    Opt(:editable, :hstretch),
                    _("De&vice"),
                    devs
                  )
                )
              ),
              # ComboBox label
              InputField(
                Id(:options),
                Opt(:hstretch),
                Label.Options,
                Ops.get_string(entry, 5, "")
              )
            ),
            HSpacing(1),
            HBox(
              PushButton(Id(:ok), Opt(:default), Label.OKButton),
              PushButton(Id(:cancel), Label.CancelButton)
            )
          )
        )
      )

      # Allow declaring route without iface (for gateway) #93996
      # if empty, use '-' which stands for any
      if Ops.get_string(entry, 4, "") != ""
        UI.ChangeWidget(Id(:device), :Value, Ops.get_string(entry, 4, ""))
      else
        UI.ChangeWidget(Id(:device), :Items, devs)
      end
      UI.ChangeWidget(
        Id(:destination),
        :ValidChars,
        Ops.add(Ops.add(IP.ValidChars, "default"), "/-")
      )
      UI.ChangeWidget(Id(:gateway), :ValidChars, Ops.add(IP.ValidChars, "-"))
      UI.ChangeWidget(
        Id(:genmask),
        :ValidChars,
        Ops.add(Netmask.ValidChars, "-")
      )

      if entry == term(:empty)
        UI.SetFocus(Id(:destination))
      else
        UI.SetFocus(Id(:gateway))
      end

      ret = nil
      route = nil

      loop do
        route = nil
        ret = UI.UserInput
        break if ret != :ok

        route = Item(Id(id))
        val = Convert.to_string(UI.QueryWidget(Id(:destination), :Value))
        slash = Builtins.search(val, "/")
        noprefix = slash.nil? ? val : Builtins.substring(val, 0, slash)
        if val != "default" && !IP.Check(noprefix)
          # Popup::Error text
          Popup.Error(_("Destination is invalid."))
          UI.SetFocus(Id(:destination))
          next
        end
        route = Builtins.add(route, val)
        val = Convert.to_string(UI.QueryWidget(Id(:gateway), :Value))
        if val != "-" && !IP.Check(val)
          # Popup::Error text
          Popup.Error(_("Gateway IP address is invalid."))
          UI.SetFocus(Id(:gateway))
          next
        end
        route = Builtins.add(route, val)
        val = Convert.to_string(UI.QueryWidget(Id(:genmask), :Value))
        if val != "-" && val != "0.0.0.0" && !Netmask.Check(val)
          # Popup::Error text
          Popup.Error(_("Subnetmask is invalid."))
          UI.SetFocus(Id(:genmask))
          next
        end
        route = Builtins.add(route, val)
        val = Convert.to_string(UI.QueryWidget(Id(:device), :Value))
        route = Builtins.add(route, val)
        val = Convert.to_string(UI.QueryWidget(Id(:options), :Value))
        route = Builtins.add(route, val)
        break
      end

      UI.CloseDialog
      return nil if ret != :ok
      Builtins.y2debug("route=%1", route)
      deep_copy(route)
    end

    def initRouting(_key)
      route_conf = deep_copy(Routing.Routes)

      # reset, so that UI really reflect current state
      # maplist below will supply correct data, if there are some
      @defgw = ""
      @defgwdev = "-"
      @defgw6 = ""
      @defgwdev6 = "-"
      @r_items = []

      # make ui items from the routes list
      item = nil

      Builtins.maplist(route_conf) do |r|
        if Ops.get_string(r, "destination", "") == "default" &&
            !Builtins.issubstring(Ops.get_string(r, "extrapara", ""), "metric")
          if IP.Check4(Ops.get_string(r, "gateway", ""))
            @defgw = Ops.get_string(r, "gateway", "")
            @defgwdev = Ops.get_string(r, "device", "")
          else
            @defgw6 = Ops.get_string(r, "gateway", "")
            @defgwdev6 = Ops.get_string(r, "device", "")
          end
        else
          item = Item(
            Id(Builtins.size(@r_items)),
            Ops.get_string(r, "destination", ""),
            Ops.get_string(r, "gateway", ""),
            Ops.get_string(r, "netmask", ""),
            Ops.get_string(r, "device", ""),
            Ops.get_string(r, "extrapara", "")
          )
          @r_items = Builtins.add(@r_items, item)
        end
      end

      Builtins.y2debug("table_items=%1", @r_items)

      UI.ChangeWidget(:gw, :Value, @defgw)
      UI.ChangeWidget(:gw6, :Value, @defgw6)
      UI.ChangeWidget(Id(:gw), :ValidChars, IP.ValidChars)
      UI.ChangeWidget(Id(:table), :Items, @r_items)
      UI.ChangeWidget(Id(:forward_v4), :Value, Routing.Forward_v4)
      UI.ChangeWidget(Id(:forward_v6), :Value, Routing.Forward_v6)
      UI.SetFocus(Id(:gw))

      # #178538 - disable routing dialog when NetworkManager is used
      # but instead of default route (#299448) - NM reads it
      enabled = !NetworkService.is_network_manager

      UI.ChangeWidget(Id(:table), :Enabled, enabled)
      UI.ChangeWidget(Id(:forward_v4), :Enabled, enabled)
      UI.ChangeWidget(Id(:forward_v6), :Enabled, enabled)
      disable_unconfigureable_items(
        [:gw, :gw6, :gw6dev, :table, :add, :edit, :delete],
        false
      )
      if !Lan.ipv6
        UI.ChangeWidget(Id(:gw6), :Enabled, false)
        UI.ChangeWidget(Id(:gw6dev), :Enabled, false)
      end

      devs = Routing.GetDevices
      devs = Builtins.add(devs, "-")
      UI.ChangeWidget(:gw4dev, :Items, devs)
      UI.ChangeWidget(:gw4dev, :Value, @defgwdev)
      UI.ChangeWidget(:gw6dev, :Items, devs)
      UI.ChangeWidget(:gw6dev, :Value, @defgwdev6)

      nil
    end

    def handleRouting(_key, event)
      event = deep_copy(event)
      enabled = !NetworkService.is_network_manager
      devs = Routing.GetDevices
      devs = Builtins.add(devs, "-")
      cur = Convert.to_integer(UI.QueryWidget(Id(:table), :CurrentItem))
      item = nil

      if Ops.get_string(event, "EventReason", "") == "Activated" ||
          Ops.get_string(event, "EventReason", "") == "ValueChanged"
        case Ops.get_symbol(event, "ID", :nil)
        when :add
          item = RoutingEditDialog(
            Builtins.size(@r_items),
            term(:empty),
            devs
          )

          if !item.nil?
            @r_items = Builtins.add(@r_items, item)
            UI.ChangeWidget(Id(:table), :Items, @r_items)
          end
        when :delete
          @r_items = Builtins.filter(@r_items) do |e|
            cur != Ops.get(e, [0, 0])
          end
          UI.ChangeWidget(Id(:table), :Items, @r_items)
        when :edit
          @cur_item = Builtins.filter(@r_items) do |e|
            cur == Ops.get(e, [0, 0])
          end

          item = Ops.get(@cur_item, 0)
          @dev = Ops.get_string(item, 4, "")
          if @dev != "" && !Builtins.contains(devs, @dev)
            devs = Builtins.add(devs, @dev)
          end
          devs = Builtins.sort(devs)

          item = RoutingEditDialog(cur, item, devs)
          if !item.nil?
            @r_items = Builtins.maplist(@r_items) do |e|
              next deep_copy(item) if cur == Ops.get_integer(e, [0, 0], -1)
              deep_copy(e)
            end
            UI.ChangeWidget(Id(:table), :Items, @r_items)
            UI.ChangeWidget(Id(:table), :CurrentItem, cur)
          end
        end
      end
      UI.ChangeWidget(Id(:add), :Enabled, enabled)
      UI.ChangeWidget(
        Id(:edit),
        :Enabled,
        enabled && Ops.greater_than(Builtins.size(@r_items), 0)
      )
      UI.ChangeWidget(
        Id(:delete),
        :Enabled,
        enabled && Ops.greater_than(Builtins.size(@r_items), 0)
      )
      nil
    end

    def validateRouting(_key, _event)
      gw = UI.QueryWidget(Id(:gw), :Value)
      if gw != "" && !IP.Check(gw)
        Popup.Error(_("The default gateway is invalid."))
        UI.SetFocus(Id(:gw))
        return false
      else
        return true
      end
    end

    def storeRouting(_key, _event)
      route_conf = Builtins.maplist(@r_items) do |e|
        {
          "destination" => Ops.get_string(e, 1, ""),
          "gateway"     => Ops.get_string(e, 2, ""),
          "netmask"     => Ops.get_string(e, 3, ""),
          "device"      => Ops.get_string(e, 4, ""),
          "extrapara"   => Ops.get_string(e, 5, "")
        }
      end

      @defgw = UI.QueryWidget(Id(:gw), :Value)
      @defgwdev = UI.QueryWidget(Id(:gw4dev), :Value)
      @defgw6 = UI.QueryWidget(Id(:gw6), :Value)
      @defgwdev6 = UI.QueryWidget(Id(:gw6dev), :Value)

      if @defgw != ""
        route_conf = Builtins.add(
          route_conf,
          "destination" => "default",
          "gateway"     => @defgw,
          "netmask"     => "-",
          "device"      => @defgwdev
        )
      end

      if @defgw6 != ""
        route_conf = Builtins.add(
          route_conf,
          "destination" => "default",
          "gateway"     => @defgw6,
          "netmask"     => "-",
          "device"      => @defgwdev6
        )
      end

      Routing.Routes = deep_copy(route_conf)
      Routing.Forward_v4 = UI.QueryWidget(Id(:forward_v4), :Value)
      Routing.Forward_v6 = UI.QueryWidget(Id(:forward_v6), :Value)

      nil
    end

    # Main routing dialog
    # @return dialog result
    def RoutingMainDialog
      caption = _("Routing Configuration")

      functions = {
        "init"  => fun_ref(method(:initRouting), "void (string)"),
        "store" => fun_ref(method(:storeRouting), "void (string, map)"),
        :abort  => fun_ref(method(:ReallyAbort), "boolean ()")
      }

      contents = VBox("ROUTING")

      Wizard.HideBackButton

      CWM.ShowAndRun(
        "widget_descr"       => @wd_routing,
        "contents"           => contents,
        "caption"            => caption,
        "back_button"        => Label.BackButton,
        "next_button"        => Label.NextButton,
        "fallback_functions" => functions
      )
    end
  end
end
