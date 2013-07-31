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
# File:
#   include/network/isdn/interface.ycp
#
# Package:
#   Configuration of network
#
# Summary:
#   ISDN network interface configuration dialog
#
# Authors:
#   Karsten Keil <kkeil@suse.de>
#
#
module Yast
  module NetworkIsdnInterfaceInclude
    def initialize_network_isdn_interface(include_target)
      Yast.import "UI"

      textdomain "network"

      Yast.import "Call"
      Yast.import "CWM"
      Yast.import "ISDN"
      Yast.import "Label"
      Yast.import "Popup"
      Yast.import "Provider"
      Yast.import "SuSEFirewall4Network"
      Yast.import "Wizard"

      Yast.include include_target, "network/dsl/dialogs.rb"
      Yast.include include_target, "network/widgets.rb"
    end

    # Dialog for ISDN interface selection
    # @param [Symbol] op operation
    #		`hw  called after HW config
    #		`add call from overview
    # @return [Object] user input

    def isdn_if_sel(op)
      # DIALOG TEXTS

      # title of ISDN service selection dialog
      caption = _("ISDN Service Selection")
      helptext = ""

      if ISDN.have_dsl
        helptext = Ops.add(
          helptext,
          # conditional help text 1/4
          _(
            "<p>If you have a combined ISDN and DSL CAPI controller, configure your DSL\n" +
              "connection via <b>Add DSL CAPI Interface</b>. You can also do this later\n" +
              "in the DSL configuration dialog.</p>\n"
          )
        )
      end

      helptext = Ops.add(
        helptext,
        # help text 1/4
        _(
          "<p>For networking over ISDN, there are two types of interfaces:\n" +
            "<b>RawIP</b> and <b>SyncPPP</b>. In most cases, use SyncPPP. It is\n" +
            "the default for all common Internet providers.</p>\n"
        )
      )

      helptext = Ops.add(
        helptext,
        # helptext text 2/4
        _(
          "<p>To switch between various Internet providers, an\n" +
            "interface for each provider is not required. Simply add multiple providers to the\n" +
            "same interface.</p>\n"
        )
      )

      helptext = Ops.add(
        helptext,
        # helptext text 3/4
        _(
          "<p>To avoid adding an interface now, use\n<b>Skip</b> not to enter the interface and provider dialogs.</p>"
        )
      )


      if ISDN.only_dsl
        helptext =
          # conditional help text 1/1
          _(
            "<p>You have a DSL CAPI controller.  Configure your DSL\n" +
              "connection via <b>Add DSL CAPI Interface</b>. You can also do this later\n" +
              "in the DSL configuration dialog.</p>"
          )
      end


      # DIALOG CONTENTS
      network = VBox()
      network = Builtins.add(network, VSpacing(0.5))
      if ISDN.have_dsl
        # PushButton label to select the next Dialog
        network = Builtins.add(
          network,
          PushButton(
            Id(:AddDSLPPP),
            Opt(:hstretch),
            _("Add &DSL CAPI Interface")
          )
        )
      end
      # PushButton label to select the next Dialog
      if !ISDN.only_dsl
        network = Builtins.add(
          network,
          PushButton(
            Id(:AddSyncPPP),
            Opt(:hstretch),
            _("Add New &SyncPPP Network Interface")
          )
        )
        # PushButton label to select the next Dialog
        network = Builtins.add(
          network,
          PushButton(
            Id(:AddRawIP),
            Opt(:hstretch),
            _("Add New Raw&IP Network Interface")
          )
        )
        # PushButton label to select the next Dialog
        network = Builtins.add(
          network,
          PushButton(
            Id(:AddProvider),
            Opt(:hstretch),
            _("Add &Provider to Existing Interface")
          )
        )
      end
      network = Builtins.add(network, VSpacing(0.5))

      contents = HVSquash(
        # Frame title
        Frame(
          _("Network Services"),
          HBox(HSpacing(0.5), network, HSpacing(0.5))
        )
      )

      # DIALOG PREPARE

      # PushButton label to not enter any sub dialogs
      Wizard.SetNextButton(:next, _("S&kip"))
      Wizard.SetContents(caption, contents, helptext, true, true)

      UI.ChangeWidget(Id(:AddProvider), :Enabled, false) if ISDN.CountIF == 0
      ISDN.skip = false

      # MAIN CYCLE
      ret = nil
      while true
        ret = UI.UserInput

        # abort?
        if ret == :abort || ret == :cancel
          if Popup.ReallyAbort(true)
            break
          else
            next
          end
        elsif ret == :back
          break
        elsif ret == :next
          break
        elsif ret == :AddDSLPPP
          dslpara = {
            "type"      => "dsl",
            "name"      => Ops.get_string(ISDN.hw_device, "NAME", "unknown"),
            "unique"    => Ops.get_string(ISDN.hw_device, "UDI", ""),
            "pppmode"   => "capi-adsl",
            "startmode" => "manual"
          }
          ret = Call.Function("dsl", [path(".capiadsl"), dslpara])
        elsif ret == :AddSyncPPP
          ISDN.Commit if op == :hw && ISDN.type == "contr"
          ISDN.AddIf("syncppp")
          Provider.Add("isdn")
          break
        elsif ret == :AddRawIP
          ISDN.Commit if op == :hw && ISDN.type == "contr"
          ISDN.AddIf("rawip")
          Provider.Add("isdn")
          break
        elsif ret == :AddProvider
          ISDN.Commit if op == :hw && ISDN.type == "contr"
          ISDN.operation = :addprov
          Provider.Add("isdn")
          break
        else
          Builtins.y2error("unexpected retcode: %1", ret)
          next
        end
      end
      if ret == :next
        Builtins.y2debug("Provider::Current=%1", Provider.Current)
        Builtins.y2debug("ISDN::interface=%1", ISDN.interface)
        ISDN.skip = true
      end

      deep_copy(ret)
    end

    # Dialog for ISDN interface settings
    # @return [Object] user input
    def interface_dialog
      # PREPARE VARIABLES
      msn = Ops.get_string(ISDN.interface, "MSN", "0")
      startmode = Ops.get_string(ISDN.interface, "STARTMODE", "manual")
      usercontrol = Ops.get_string(ISDN.interface, "USERCONTROL", "no") == "yes"
      syncppp = Ops.get_string(ISDN.interface, "PROTOCOL", "syncppp") == "syncppp"
      chargeHUP = Ops.get_string(ISDN.interface, "CHARGEHUP", "on") == "on"
      multilink = Ops.get_string(ISDN.interface, "MULTILINK", "no") == "yes"
      firewall = Ops.get_string(ISDN.interface, "FIREWALL", "yes") == "yes"
      # temp var while we're in the detailed dialog
      efwi = Ops.get_boolean(ISDN.interface, "efwi")
      _ExternalFwInterface = true
      devstr = Builtins.sformat("%1%2", syncppp ? "ippp" : "isdn", ISDN.device)

      _ExternalFwInterface = false if efwi == false
      if ISDN.operation == :editif && efwi == nil
        _ExternalFwInterface = SuSEFirewall4Network.IsProtectedByFirewall(
          devstr
        )
      end
      ISDN.interface = Builtins.remove(ISDN.interface, "efwi") if efwi != nil
      Builtins.y2debug("ExternalFwInterface=%1", _ExternalFwInterface)

      # DIALOG TEXTS
      fcaption = ISDN.operation == :editif ?
        # dialog caption, %1: SyncPPP or RawIP, %2: interface name, eg. ppp0
        _("Edit %1 Interface %2") :
        # dialog caption, %1: SyncPPP or RawIP, %2: interface name, eg. ppp0
        _("Add %1 Interface %2")
      caption = Builtins.sformat(
        fcaption,
        syncppp ? "SyncPPP" : "RawIP",
        devstr
      )

      Ops.set(
        @widget_descr,
        "STARTMODE",
        MakeStartmode(["auto", "hotplug", "manual", "off"])
      )

      helptext =
        # help text 1/5
        _(
          "<p>My phone number --  As your own telephone number (MSN), put in your \n" +
            "telephone number (without area code) if your ISDN card is connected directly\n" +
            "to the phone company-provided socket. If it is connected to a PBX, put in the\n" +
            "MSN stored in the PBX (e.g., your phone extension or the last digit or digits\n" +
            "of your phone extension) . If this fails, try using 0, which normally means\n" +
            "the default MSN is actually used.</p>"
        )

      helptext = Ops.add(
        helptext,
        Ops.get_string(@widget_descr, ["STARTMODE", "help"], "")
      )

      helptext = Ops.add(
        helptext,
        # help text 3/5
        _(
          "<p>If you select manual, start and stop the service manually by\n" +
            "issuing the following commands (while logged in as 'root'):\n" +
            "<tt>\n" +
            " <br> <b>start: </b>ifup ippp0\n" +
            " <br> <b>stop : </b>ifdown ippp0\n" +
            " <br>\n" +
            "</tt>\n" +
            "Note: ippp0 is an example</p>"
        )
      )

      helptext = Ops.add(
        helptext,
        Ops.get_string(@widget_descr, ["USERCONTROL", "help"], "")
      )

      helptext = Ops.add(
        helptext,
        # help text 4/5
        _(
          "<p>Selecting <b>channel bundling</b> sets up a 128-kBit connection\n" +
            "also known as Multilink PPP. To activate or deactivate the second channel,\n" +
            "use the following commands:\n" +
            "<tt>\n" +
            " <br> isdnctrl addlink ippp0\n" +
            " <br> isdnctrl removelink ippp0\n" +
            " <br>\n" +
            "</tt>\n" +
            "You can also install the package <b>xibod</b> to have this happen automatically. If\n" +
            "there is a demand for more bandwidth, it adds a channel. If the traffic goes down, it \n" +
            "removes a channel.\n" +
            "</p>\n"
        )
      )

      helptext = Ops.add(
        helptext,
        # help text 5/5
        _(
          "<p>Selecting\n" +
            "<b>External Firewall Interface</b> activates the firewall\n" +
            "and sets this interface as external.\n" +
            "<b>Restart Firewall</b> restarts the firewall if a connection is established.\n" +
            "</p>"
        )
      )


      # DIALOG CONTENTS
      provlist = []
      prov = VSpacing(0.0)
      afterprov = 0.0
      if ISDN.operation == :editif
        Provider.Add("isdn")
        provlist = Provider.GetProviders("isdn", "_custom", ISDN.provider_file)
        Builtins.y2debug("provlist: %1", provlist)
        # ComboBox label
        prov = Left(ComboBox(Id(:prov), _("D&efault Provider"), provlist))
        afterprov = 0.5
      end

      Builtins.y2debug("device %1", devstr)

      _FirewallCheckbox = HBox(
        HWeight(
          1,
          Left(
            CheckBox(
              Id(:FirewallExt),
              _("External Fire&wall Interface"),
              _ExternalFwInterface
            )
          )
        ),
        HSpacing(1),
        HWeight(
          1,
          # CheckBox label
          Left(CheckBox(Id(:Firewall), _("Restart Fire&wall"), firewall))
        )
      )

      widgets = CWM.CreateWidgets(["USERCONTROL", "STARTMODE"], @widget_descr)

      contents = Top(
        VBox(
          VSpacing(1.5),
          # Frame title
          Frame(
            _("Connection Settings"),
            HBox(
              HSpacing(1),
              VBox(
                VSpacing(0.5),
                # TextEntry label
                Left(TextEntry(Id(:msn), _("My &Phone Number"), msn)),
                VSpacing(0.5),
                HBox(
                  VBox(
                    HBox(
                      HWeight(
                        1,
                        Top(
                          # STARTMODE
                          Left(Ops.get_term(widgets, [1, "widget"], Empty()))
                        )
                      ),
                      HSpacing(1),
                      HWeight(
                        1,
                        Top(
                          VBox(
                            Label(""),
                            Left(Ops.get_term(widgets, [0, "widget"], Empty()))
                          )
                        )
                      )
                    ),
                    VSpacing(0.5),
                    prov,
                    VSpacing(afterprov),
                    # CheckBox label
                    Left(CheckBox(Id(:chargehup), _("Charge&HUP"), chargeHUP)),
                    VSpacing(0.5),
                    # CheckBox label
                    Left(
                      CheckBox(
                        Id(:multilink),
                        _("Ch&annel Bundling"),
                        multilink
                      )
                    ),
                    VSpacing(0.5),
                    # CheckBox label
                    _FirewallCheckbox,
                    VSpacing(0.5)
                  )
                )
              ),
              HSpacing(1)
            )
          ),
          VSpacing(0.5),
          # PushButton label
          PushButton(Id(:detail), _("&Details..."))
        )
      )


      # DIALOG PREPARE
      Wizard.SetContentsButtons(
        caption,
        contents,
        helptext,
        Label.BackButton,
        Label.NextButton
      )

      UI.ChangeWidget(Id("USERCONTROL"), :Value, usercontrol)
      UI.ChangeWidget(Id("STARTMODE"), :Value, startmode)
      UI.SetFocus(Id(:msn))

      # MAIN CYCLE
      ret = nil
      while true
        # We need ":"  for NI1 SPID and "VB" in future (for pending DATA over VOICE patch)
        # it should not hurt if we enable this now here, since the chance that a
        # customer enter V or B by accident is very low
        # since VB is only allowed as first char, maybe we should make a post
        # check for it too
        UI.ChangeWidget(Id(:msn), :ValidChars, "0123456789:BV")

        ret = UI.UserInput

        # abort?
        if ret == :abort || ret == :cancel
          if Popup.ReallyAbort(true)
            break
          else
            next
          end
        elsif ret == :back
          break
        elsif ret == :next || ret == :detail
          msn = Convert.to_string(UI.QueryWidget(Id(:msn), :Value))
          startmode = Convert.to_string(UI.QueryWidget(Id("STARTMODE"), :Value))
          usercontrol = Convert.to_boolean(
            UI.QueryWidget(Id("USERCONTROL"), :Value)
          )
          multilink = Convert.to_boolean(UI.QueryWidget(Id(:multilink), :Value))
          chargeHUP = Convert.to_boolean(UI.QueryWidget(Id(:chargehup), :Value))
          # check_*
          break
        else
          Builtins.y2error("unexpected retcode: %1", ret)
          next
        end
      end
      if ret == :next || ret == :detail
        # update firewall info
        # Better update allways, maybe somebody changed it

        firewall = Convert.to_boolean(UI.QueryWidget(Id(:Firewall), :Value))
        _ExternalFwInterface = Convert.to_boolean(
          UI.QueryWidget(Id(:FirewallExt), :Value)
        )
        SuSEFirewall4Network.ProtectByFirewall(
          devstr,
          "EXT",
          _ExternalFwInterface
        )

        # UPDATE VARIABLES
        ISDN.interface = Builtins.union(
          ISDN.interface,
          {
            "MSN"         => msn,
            "STARTMODE"   => startmode,
            "USERCONTROL" => usercontrol ? "yes" : "no",
            "MULTILINK"   => multilink ? "yes" : "no",
            "CHARGEHUP"   => chargeHUP ? "on" : "off",
            "FIREWALL"    => firewall ? "yes" : "no"
          }
        )
        if ret == :detail #temporary
          ISDN.interface = Builtins.add(
            ISDN.interface,
            "efwi",
            _ExternalFwInterface
          )
        end
        if ISDN.operation == :editif
          ISDN.provider_file = Convert.to_string(
            UI.QueryWidget(Id(:prov), :Value)
          )
        end
      end
      deep_copy(ret)
    end
  end
end
