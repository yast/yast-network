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
# File:	include/network/dsl/dialogs.ycp
# Package:	Network configuration
# Summary:	Configuration dialogs for DSL
# Authors:	Michal Svec <msvec@suse.cz>
#
module Yast
  module NetworkDslDialogsInclude
    def initialize_network_dsl_dialogs(include_target)
      Yast.import "UI"

      textdomain "network"

      Yast.import "Call"
      Yast.import "CWM"
      Yast.import "DSL"
      Yast.import "IP"
      Yast.import "Label"
      Yast.import "Lan"
      Yast.import "NetworkInterfaces"
      Yast.import "Popup"
      Yast.import "SuSEFirewall4Network"
      Yast.import "Wizard"
      Yast.import "LanItems"
      Yast.import "Hostname"

      Yast.include include_target, "network/runtime.rb"
      Yast.include include_target, "network/routines.rb"
      Yast.include include_target, "network/widgets.rb"
      Yast.include include_target, "network/installation/dialogs.rb"
    end

    # DSL device dialog
    # @return dialog result
    def DSLDialog
      Ops.set(
        @widget_descr,
        "STARTMODE",
        MakeStartmode(["auto", "hotplug", "manual", "off"])
      )

      # DSL dialog caption
      caption = _("DSL Configuration")

      # DSL dialog help 1/8
      helptext = Ops.add(
        Ops.add(
          Ops.add(
            _(
              "<p>Here, set the most important settings\nfor the DSL connection.</p>\n"
            ) +
              # DSL dialog help 2/8
              _(
                "<p>First, choose your <b>PPP mode</b>. This is either\n" +
                  "<i>PPP over Ethernet</i> (PPPoE), <i>PPP over ATM</i> (PPPoATM),\n" +
                  "<i>CAPI for ADSL</i> or <i>Point to Point Tunneling Protocol</i> (PPTP).\n" +
                  "Use <i>PPP over Ethernet</i> if your DSL modem is connected via ethernet to your computer.\n" +
                  "Use <i>Point to Point Tunneling Protocol</i> if you want to connect to a VPN server.\n" +
                  "If you are not sure which mode to use, ask your provider. </p>"
              ) +
              # DSL dialog help 3/8
              _(
                "<p>If you are using <i>PPP over Ethernet</i>, first configure your\nethernet card.</p>"
              ) +
              # DSL dialog help 4/8
              _(
                "<p>The <b>PPP Mode-Dependent Settings</b> are settings required to set up\n" +
                  "your DSL connection. <b>VPI/VCI</b> makes sense only for <i>PPP over ATM</i>\n" +
                  "connections, <b>Ethernet Card</b> is needed for <i>PPP over Ethernet</i>\n" +
                  "connections.</p>\n"
              ) +
              # DSL dialog help 5/8
              _(
                "<p><b>For PPPoATM, enter your VPI/VCI pair, for example, <i>0.38</i>\nfor British Telecom. If unsure, ask your provider.</p>"
              ) +
              # DSL dialog help 6/8
              _(
                "<p>For PPPoE, enter the device of the ethernet card to which your DSL\n" +
                  "modem is connected. If you did not set up your ethernet card yet, do\n" +
                  "so by pressing <b>Configure Network Cards</b>.</p>"
              ) +
              # DSL dialog help 7/8
              _("<p>For PPTP, enter the server name or IP address.</p>"),
            Ops.get_string(@widget_descr, ["STARTMODE", "help"], "")
          ),
          # DSL dialog help 8/8
          _(
            "<p>Activation during boot may\nbe appropriate for dial-on-demand connections.</p>"
          )
        ),
        Ops.get_string(@widget_descr, ["USERCONTROL", "help"], "")
      )

      pppmode = DSL.pppmode
      pppmode = "pppoe" if pppmode == nil || pppmode == ""

      pppmodes = [
        # ComboBox item
        Item(Id("pppoe"), _("PPP over Ethernet"), pppmode == "pppoe"),
        # ComboBox item
        Item(Id("pppoatm"), _("PPP over ATM"), pppmode == "pppoatm"),
        # ComboBox item
        Item(Id("capi-adsl"), _("CAPI for ADSL"), pppmode == "capi-adsl"),
        # ComboBox item
        Item(
          Id("pptp"),
          _("Point to Point Tunneling Protocol"),
          pppmode == "pptp"
        )
      ]
      # ComboBox label
      pppwidget = Left(
        ComboBox(
          Id(:pppmode),
          Opt(:hstretch, :notify),
          _("PPP &Mode"),
          pppmodes
        )
      )

      vpivci = DSL.vpivci
      startmode = DSL.startmode
      usercontrol = DSL.usercontrol
      interface = DSL.interface
      modemip = DSL.modemip
      ifaces = []


      #   define void UpdateInterfaces() {
      items = getNetDeviceItems
      if Ops.greater_than(Builtins.size(items), 0) && interface == ""
        interface = Ops.get(items, 0, "")
      end
      # FIXME Why is not the current interface added?
      if false && !Builtins.contains(ifaces, interface) #interface != "" &&
        ifaces = Builtins.add(ifaces, interface)
      end

      #}

      # FIXME: #suse27137
      #    UpdateInterfaces();
      if Ops.less_than(Builtins.size(items), 1)
        NetworkInterfaces.Push
        if Lan.Propose
          #	    UpdateInterfaces();
          # list<term (term (string), string, boolean)>
          i = Ops.get_string(ifaces, [0, 0, 0], "")
          Builtins.y2milestone("i=%1", i)
          Lan.Edit(i)
          LanItems.bootproto = ""
          LanItems.ipaddr = ""
          LanItems.Commit
        end
        NetworkInterfaces.Pop
      end

      widgets = CWM.CreateWidgets(["USERCONTROL", "STARTMODE"], @widget_descr)


      #    list<string> items = NetworkInterfaces::List("");

      # NetworkInterfaces::Read();
      #     map <string, string> device_descr = GetDeviceDescription(items[0]:"");
      # y2internal("device_descr %1", device_descr);
      # string connection_text = _("%1 - %2 (%3)");

      # DSL dialog contents
      contents = HBox(
        HSpacing(6),
        # Frame label
        Frame(
          _("DSL Connection Settings"),
          HBox(
            HSpacing(2),
            VBox(
              VSpacing(1),
              pppwidget,
              VSpacing(1),
              # Frame label
              Frame(
                _("PPP Mode-Dependent Settings"),
                HBox(
                  HSpacing(2),
                  VBox(
                    VSpacing(0.2),
                    # TextEntry label
                    TextEntry(Id(:vpivci), _("&VPI/VCI"), vpivci),
                    VSpacing(0.2),
                    Frame(
                      _("&Ethernet Card"),
                      HBox(
                        # RadioButton label
                        #	`Left(`ReplacePoint(`id(`rp), `Label(`id(`yes), sformat(connection_text, device_descr["name"]:"", device_descr["type"]:"", device_descr["ipaddr"]:_("No IP address assigned"))))),
                        # push button label
                        getDeviceContens(interface)
                      )
                    ),
                    PushButton(Id(:lan), _("&Configure Network Cards")),
                    VSpacing(0.2),
                    # TextEntry label
                    TextEntry(
                      Id(:modemip),
                      _("&Server Name or IP Address"),
                      modemip
                    )
                  ),
                  HSpacing(2)
                )
              ),
              VSpacing(1),
              # STARTMODE
              Left(Ops.get_term(widgets, [1, "widget"], Empty())),
              VSpacing(0.5),
              # USERCONTROL
              # 0 is index to CreateWidgets... ugly
              Left(Ops.get_term(widgets, [0, "widget"], Empty())),
              VSpacing(1)
            ),
            HSpacing(2)
          )
        ),
        HSpacing(6)
      )

      Wizard.SetContentsButtons(
        caption,
        contents,
        helptext,
        Label.BackButton,
        Label.NextButton
      )

      UI.ChangeWidget(Id("USERCONTROL"), :Value, usercontrol)
      UI.ChangeWidget(Id("STARTMODE"), :Value, startmode)

      UI.ChangeWidget(Id(:vpivci), :Enabled, pppmode == "pppoatm")
      enableDevices(pppmode == "pppoe" || pppmode == "pptp")
      UI.ChangeWidget(
        Id(:lan),
        :Enabled,
        pppmode == "pppoe" || pppmode == "pptp"
      )
      UI.ChangeWidget(Id(:modemip), :Enabled, pppmode == "pptp")

      ret = nil
      while true
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
          # check_*
          pppmode = Convert.to_string(UI.QueryWidget(Id(:pppmode), :Value))
          #	    interface = (string) UI::QueryWidget(`id(`interface), `Value);
          vpivci = Convert.to_string(UI.QueryWidget(Id(:vpivci), :Value))
          modemip = Convert.to_string(UI.QueryWidget(Id(:modemip), :Value))
          if pppmode == "pppoatm" && vpivci == ""
            # Popup text
            Popup.Error(_("Enter the VPI/VCI."))
            UI.SetFocus(Id(:vpivci))
            next
          end
          if (pppmode == "pppoe" || pppmode == "pptp") && interface == ""
            # Popup text
            Popup.Error(
              _("At least one ethernet interface must be configured.")
            )
            UI.SetFocus(Id(:lan))
            next
          end
          if pppmode == "pptp" && !IP.Check4(modemip) &&
              !Hostname.CheckDomain(modemip)
            # Popup text
            Popup.Error(_("Server IP address or domain name is invalid."))
            UI.SetFocus(Id(:modemip))
            next
          end
          break
        elsif ret == :pppmode
          pppmode = Convert.to_string(UI.QueryWidget(Id(:pppmode), :Value))
          UI.ChangeWidget(Id(:vpivci), :Enabled, pppmode == "pppoatm")
          enableDevices(pppmode == "pppoe" || pppmode == "pptp")
          #	    UI::ChangeWidget(`id(`interface), `Enabled, pppmode == "pppoe" || pppmode == "pptp");
          UI.ChangeWidget(
            Id(:lan),
            :Enabled,
            pppmode == "pppoe" || pppmode == "pptp"
          )
          UI.ChangeWidget(Id(:modemip), :Enabled, pppmode == "pptp")
          next
        elsif ret == :lan
          # WFM::CallFunction("lan_proposal", ["AskUser"]);
          NetworkInterfaces.Push
          Call.Function("lan_proposal", ["AskUser"])
          NetworkInterfaces.Pop
          items = getNetDeviceItems
          refreshDevice(interface)
          #	    interface = (string) UI::QueryWidget(`id(`interface), `Value);
          #	    UpdateInterfaces();
          #	    UI::ReplaceWidget(`id(`rp), `ComboBox(`id(`interface), _("&Ethernet Card"), ifaces));
          next
        elsif ret == :net_expert
          interface = handleDevice(items, interface)
        else
          Builtins.y2error("Unexpected return code: %1", ret)
          next
        end
      end

      if ret == :next
        pppmode = Convert.to_string(UI.QueryWidget(Id(:pppmode), :Value))
        DSL.pppmode = pppmode
        if pppmode == "pppoe" || pppmode == "pptp"
          DSL.interface = interface #(string) UI::QueryWidget(`id(`interface), `Value);
          # If firewall is active and interface in no zone, nothing
          # gets through (#47309) so add it to the external zone
          if SuSEFirewall4Network.IsOn
            SuSEFirewall4Network.ProtectByFirewall(DSL.interface, "EXT", true)
          end
        end
        if pppmode == "pppoatm"
          DSL.vpivci = Convert.to_string(UI.QueryWidget(Id(:vpivci), :Value))
        end
        if pppmode == "pptp"
          DSL.modemip = Convert.to_string(UI.QueryWidget(Id(:modemip), :Value))
        end
        DSL.startmode = Convert.to_string(
          UI.QueryWidget(Id("STARTMODE"), :Value)
        )
        DSL.usercontrol = Convert.to_boolean(
          UI.QueryWidget(Id("USERCONTROL"), :Value)
        )
      end

      deep_copy(ret)
    end
  end
end
