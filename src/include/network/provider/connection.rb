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
# File:	include/network/provider/connection.ycp
# Package:	Network configuration
# Summary:	Connection configuration dialogs
# Authors:	Michal Svec <msvec@suse.cz>
#
module Yast
  module NetworkProviderConnectionInclude
    def initialize_network_provider_connection(include_target)
      Yast.import "UI"

      textdomain "network"

      Yast.import "DSL"
      Yast.import "IP"
      Yast.import "ISDN"
      Yast.import "Label"
      Yast.import "NetworkInterfaces"
      Yast.import "Modem"
      Yast.import "Popup"
      Yast.import "Provider"
      Yast.import "SuSEFirewall4Network"
      Yast.import "Wizard"

      Yast.include include_target, "network/routines.rb"
    end

    # Connection dialog
    # @return dialog result
    def ConnectionDialog
      type = Provider.Type

      # PREPARE VARIABLES
      _Provider = Ops.get_string(Provider.Current, "PROVIDER", "")

      startmode = ""

      demand = Ops.get_string(Provider.Current, "DEMAND", "no") == "yes"
      stupidmode = Ops.get_string(Provider.Current, "STUPIDMODE", "no") == "yes"

      modifydns = Ops.get_string(Provider.Current, "MODIFYDNS", "yes") == "yes"
      autodns = Ops.get_string(Provider.Current, "AUTODNS", "yes") == "yes"

      # hide autoreconnect from UI (bnc#558788)
      autoreconnect = Ops.get_string(Provider.Current, "AUTO_RECONNECT", "yes") == "yes"

      _DNS1 = Ops.get_string(Provider.Current, "DNS1", "")
      _DNS2 = Ops.get_string(Provider.Current, "DNS2", "")

      idletime = Ops.get_string(Provider.Current, "IDLETIME", "900")

      device = nil
      dtype = nil
      did = nil
      if type == "modem"
        dtype = Modem.type
        did = Modem.device
        startmode = Modem.startmode
      elsif type == "dsl"
        dtype = DSL.type
        did = DSL.device
      elsif type == "isdn"
        did = ISDN.device
        # FIXME: #18840
        if ISDN.type == "net"
          dtype = "ippp"
        else
          dtype = ISDN.type
        end
      else
        Builtins.y2error("Unknown type: %1", type)
        return nil
      end
      Builtins.y2debug("device %1", device)

      # the device is not a property of the provider so it may happen
      # that we do not have it. #146388
      _FirewallChecked = false
      if dtype != ""
        device = did

        adding = false
        if type == "modem"
          adding = Modem.Adding
        elsif type == "dsl"
          adding = DSL.Adding
        end

        if adding # #66478
          _FirewallChecked = true
        else
          _FirewallChecked = SuSEFirewall4Network.IsProtectedByFirewall(device)
        end
      end
      Builtins.y2debug("FirewallChecked=%1", _FirewallChecked)

      # DIALOG TEXTS

      # Connection dialog caption
      caption = _("Connection Parameters")

      # Connection dialog help 1/9
      helptext = _(
        "<p><b>Dial on Demand</b> means that the Internet\n" +
          "connection will be established automatically when data from the Internet is\n" +
          "requested. To use this feature, specify at least one <i>name server</i>. Use\n" +
          "this feature only if your Internet connection is inexpensive, because there are\n" +
          "programs that periodically request data from the Internet.</p>"
      ) +
        # Connection dialog help 2/9
        _(
          "<p>When <b>Modify DNS</b> is enabled, the <i>name server</i> will be\nchanged automatically when connected to the Internet.</p>"
        ) +
        # Connection dialog help 3/9
        _(
          "<p>If the provider does not transmit its domain name server (DNS)\n" +
            "after connecting, disable <b>Automatically Retrieve DNS</b> and\n" +
            "manually enter the DNS.</p>"
        ) +
        # Connection dialog help 4/9
        #_("<p>If <b>Automatically Reconnect</b> is enabled, the connection will
        #be reestablished automatically after failure.</p>
        #") +

        # Connection dialog help 5/9
        _(
          "<p><b>Name Servers</b> are required to convert hostnames\n" +
            "(such as www.suse.com) to IP addresses (for example, 213.95.15.200). You only\n" +
            "need to specify the name servers if you enable dial on demand or\n" +
            "disable <b>DNS Modification</b> when connected.</p>\n"
        )

      if type == "modem"
        helptext = Ops.add(
          helptext,
          # Connection dialog help 6/9
          _(
            "<p><b>Ignore Prompts</b> disables the detection of any prompts from the dial-up\n" +
              "server. If the connection build-up is slow or does not work at all, try this\n" +
              "option.</p>\n"
          )
        )
      end

      helptext = Ops.add(
        Ops.add(
          helptext,
          # Connection dialog help 7/9
          _(
            "<p>Selecting <b>External Firewall Interface</b> activates the firewall\n" +
              "and sets this interface as external.\n" +
              "Choosing this option makes dial-up connections\n" +
              "to the Internet safe from external attacks.</p>"
          )
        ),
        # Connection dialog help 8/9
        _(
          "<p>The <b>Idle Time-Out</b> specifies the time after which an idle\nconnection will be shut down (0 means the connection will not time-out).</p>\n"
        )
      )

      # if(type == "isdn")

      # FIXME Connection dialog help 8/9
      # helptext = helptext + _("<p><b>Connection details</b> help FIXME</p>") +

      # FIXME Connection dialog help 9/9
      # _("<p><b>IP details</b> help FIXME</p>");

      # DIALOG CONTENTS

      seconds = [
        "0",
        "30",
        "60",
        "90",
        "120",
        "150",
        "180",
        "240",
        "300",
        "360",
        "480",
        "600"
      ]
      if !Builtins.contains(seconds, idletime)
        seconds = Builtins.add(seconds, idletime)
      end

      seconds = Builtins.maplist(
        Convert.convert(seconds, :from => "list", :to => "list <string>")
      ) do |e|
        Item(
          Id(Builtins.sformat("%1", e)),
          Builtins.sformat(
            "%1 (%2 %3)",
            e,
            Ops.divide(
              Builtins.tofloat(e),
              Convert.convert(60, :from => "integer", :to => "float")
            ),
            _("min")
          ),
          e == idletime
        )
      end

      # Checkbox label
      # this is an external interface protected by the firewall
      _FirewallCheckbox = Left(
        CheckBox(
          Id(:Firewall),
          _("External Fire&wall Interface"),
          _FirewallChecked
        )
      )
      _FirewallCheckbox = VSpacing(0) if device == nil || type == "isdn"

      _StupidMode = VSpacing(0.1)
      if type == "modem"
        # Checkbox label
        _StupidMode = Left(
          CheckBox(Id(:stupidmode), _("I&gnore Prompts"), stupidmode)
        )
      end

      details = VSpacing(0.1)
      # FIXME if(type == "isdn")
      if false
        details = HBox(
          # Push button label
          PushButton(Id(:Details), _("&Connection Details")),
          HSpacing(0.5),
          # Push button label
          PushButton(Id(:IPDetails), _("I&P Details"))
        )
      end
      if type != "isdn"
        details = HBox(
          # Push button label
          PushButton(Id(:IPDetails), _("I&P Details"))
        )
      end

      _STARTMODE = Empty()
      if type == "modem"
        _STARTMODE = Left(
          ComboBox(
            Id(:startmode),
            _("How the interface should be set up"),
            [
              Item(Id("auto"), _("Automatically")),
              Item(Id("manual"), _("Manually")),
              Item(Id("off"), _("Off"))
            ]
          )
        )
      end

      contents = HBox(
        HSpacing(6),
        VBox(
          VSpacing(0.5),
          Left(
            HBox(
              # Label
              Label(_("Provider:")),
              HSpacing(0.5),
              Label(Opt(:outputField), _Provider)
            )
          ),
          VSpacing(0.5),
          HBox(
            VBox(
              _STARTMODE, # Checkbox label
              #		    `Left(`CheckBox(`id(`autoreconnect), `opt(`notify), _("Automatically &Reconnect"), autoreconnect))
              # Checkbox label
              Left(
                CheckBox(
                  Id(:demand),
                  Opt(:notify),
                  _("Dial on D&emand"),
                  demand
                )
              ),
              # Checkbox label
              Left(
                CheckBox(
                  Id(:modifydns),
                  Opt(:notify),
                  _("&Modify DNS When Connected"),
                  modifydns
                )
              ),
              # Checkbox label
              Left(
                CheckBox(
                  Id(:autodns),
                  Opt(:notify),
                  _("&Automatically Retrieve DNS"),
                  autodns
                )
              )
            )
          ),
          VSpacing(1),
          # Frame label
          Frame(
            Id(:nameservers),
            _("Name Servers"),
            HBox(
              # Text entry label
              TextEntry(Id(:DNS1), _("F&irst"), _DNS1),
              HSpacing(0.5),
              # Text entry label
              TextEntry(Id(:DNS2), _("&Second"), _DNS2)
            )
          ),
          VSpacing(1),
          _StupidMode,
          _FirewallCheckbox,
          VSpacing(0.5),
          # Combo box label
          Left(
            ComboBox(
              Id(:idletime),
              Opt(:editable),
              _("I&dle Time-Out (seconds)"),
              seconds
            )
          ),
          VSpacing(1),
          details
        ),
        HSpacing(6)
      )

      # DIALOG PREPARE

      Wizard.SetContentsButtons(
        caption,
        contents,
        helptext,
        Label.BackButton,
        Label.NextButton
      )

      UI.ChangeWidget(Id(:startmode), :Value, startmode) if type == "modem"
      UI.ChangeWidget(
        Id(:nameservers),
        :Enabled,
        modifydns && (demand || !autodns)
      )

      # MAIN CYCLE
      ret = nil
      while true
        ret = UI.UserInput

        # abort?
        if ret == :abort || ret == :cancel
          if ReallyAbort()
            break
          else
            next
          end
        elsif ret == :back
          break
        elsif ret == :next || ret == :Details || ret == :IPDetails
          # check_*
          if UI.QueryWidget(Id(:idletime), :Value) == ""
            # Popup text
            Popup.Error(_("Set the idle time-out."))
            UI.SetFocus(Id(:idletime))
            next
          end
          if modifydns && (demand || !autodns)
            _DNS1 = Convert.to_string(UI.QueryWidget(Id(:DNS1), :Value))
            _DNS2 = Convert.to_string(UI.QueryWidget(Id(:DNS2), :Value))
            if !IP.Check4(_DNS1)
              Popup.Error(_("The primary name server is invalid."))
              UI.SetFocus(Id(:DNS1))
              next
            end
            if Ops.greater_than(Builtins.size(_DNS2), 0) && !IP.Check4(_DNS2)
              Popup.Error(_("The secondary name server is invalid."))
              UI.SetFocus(Id(:DNS2))
              next
            end
          end
          break
        elsif ret == :demand || ret == :modifydns || ret == :autodns
          demand = Convert.to_boolean(UI.QueryWidget(Id(:demand), :Value))
          modifydns = Convert.to_boolean(UI.QueryWidget(Id(:modifydns), :Value))
          autodns = Convert.to_boolean(UI.QueryWidget(Id(:autodns), :Value))
          UI.ChangeWidget(Id(:autodns), :Value, false) if demand
          UI.ChangeWidget(
            Id(:nameservers),
            :Enabled,
            modifydns && (demand || !autodns)
          )
        else
          Builtins.y2error("unexpected retcode: %1", ret)
          next
        end
      end

      # UPDATE VARIABLES

      if ret == :next || ret == :Details || ret == :IPDetails
        demand = Convert.to_boolean(UI.QueryWidget(Id(:demand), :Value))
        modifydns = Convert.to_boolean(UI.QueryWidget(Id(:modifydns), :Value))
        autodns = Convert.to_boolean(UI.QueryWidget(Id(:autodns), :Value))
        #	autoreconnect = (boolean) UI::QueryWidget(`id(`autoreconnect), `Value);

        # update provider info
        Provider.Current = Builtins.union(
          Provider.Current,
          {
            "DEMAND"         => demand ? "yes" : "no",
            "MODIFYDNS"      => modifydns ? "yes" : "no",
            "AUTODNS"        => autodns ? "yes" : "no",
            "AUTO_RECONNECT" => autoreconnect ? "yes" : "no",
            "IDLETIME"       => UI.QueryWidget(Id(:idletime), :Value),
            "MODEMSUPPORTED" => type == "modem" ? "yes" : "no",
            "ISDNSUPPORTED"  => type == "isdn" ? "yes" : "no",
            "DSLSUPPORTED"   => type == "dsl" ? "yes" : "no"
          }
        )
        if modifydns && (demand || !autodns)
          Provider.Current = Builtins.union(
            Provider.Current,
            {
              "DNS1" => UI.QueryWidget(Id(:DNS1), :Value),
              "DNS2" => UI.QueryWidget(Id(:DNS2), :Value)
            }
          )
        end

        # update provider type-specific info
        if type == "modem"
          Provider.Current = Builtins.union(
            Provider.Current,
            {
              "STUPIDMODE" => Convert.to_boolean(
                UI.QueryWidget(Id(:stupidmode), :Value)
              ) ? "yes" : "no"
            }
          )
          Modem.startmode = Convert.to_string(
            UI.QueryWidget(Id(:startmode), :Value)
          )
        end
        # update firewall info
        if UI.WidgetExists(Id(:Firewall))
          # Update /etc/sysconfig/firewall
          #	    if(FirewallChecked != UI::QueryWidget(`id(`Firewall), `Value)) {
          _FirewallChecked = Convert.to_boolean(
            UI.QueryWidget(Id(:Firewall), :Value)
          )
          SuSEFirewall4Network.ProtectByFirewall(
            device,
            "EXT",
            _FirewallChecked
          ) 
          #	    }
        end
      end

      deep_copy(ret)
    end

    # Connection details dialog
    # @return dialog result
    def ConnectionDetailsDialog
      :abort
    end
  end
end
