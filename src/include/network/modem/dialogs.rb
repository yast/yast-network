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
# File:	include/network/modem/dialogs.ycp
# Package:	Network configuration
# Summary:	Modem configuration dialogs
# Authors:	Michal Svec <msvec@suse.cz>
#
module Yast
  module NetworkModemDialogsInclude
    def initialize_network_modem_dialogs(include_target)
      Yast.import "UI"

      textdomain "network"

      Yast.import "CWM"
      Yast.import "Label"
      Yast.import "Modem"
      Yast.import "Popup"
      Yast.import "Wizard"

      Yast.include include_target, "network/routines.rb"
      Yast.include include_target, "network/widgets.rb"
    end

    # Modem dialog
    # @param [Boolean] detected true if the type is detected
    # @return dialog result
    def ModemDialog(detected)
      # for ttySL install smartlink-softmodem package (#284287)
      if Builtins.issubstring(Modem.Device, "ttySL")
        if !Builtins.contains(Modem.Requires, "smartlink-softmodem")
          Modem.Requires = Builtins.add(Modem.Requires, "smartlink-softmodem")
        end
      end

      # PREPARE VARIABLES

      # FIXME make the Connection dialog optional in the provider dialog

      devices = Builtins.maplist(
        Builtins.toset(
          [
            Modem.Device,
            "/dev/modem",
            "/dev/ttyS0",
            "/dev/ttyS1",
            "/dev/ttyS2",
            "/dev/ttyS3",
            "/dev/ttyACM0",
            "/dev/ttyACM1",
            "/dev/ttyACM2",
            "/dev/ttyACM3"
          ]
        )
      ) do |e|
        Item(
          Id(Builtins.sformat("%1", e)),
          Builtins.sformat("%1", e),
          e == Modem.Device
        )
      end

      # DIALOG TEXTS

      # Modem dialog caption
      caption = _("Modem Parameters")

      # Modem dialog help 1/5
      helptext = _("<p>Enter all modem configuration values.</p>") +
        # Modem dialog help 2/5
        _(
          "<p><b>Modem Device</b> specifies to which port your modem is connected. ttyS0,\n" +
            "ttyS1, etc., refer to serial ports and usually correspond to COM1, COM2, etc.,\n" +
            "in DOS/Windows. ttyACM0 and ttyACM1 refer to USB ports.</p>"
        ) +
        # Modem dialog help 3/5
        _(
          "<p>If you are on a PBX, you probably need to enter a <b>Dial Prefix</b>.\nOften, this is <i>9</i> or <i>0</i>.</p>\n"
        ) +
        # Modem dialog help 4/5
        _(
          "<p>Choose <b>Dial Mode</b> according to your phone link. Most telephone\n" +
            "companies use <i>Tone Dial</i> as the <b>Dial Mode</b>. Check the additional\n" +
            "check boxes to turn on your modem speaker (<i>Speaker On</i>) or for your\n" +
            "modem to wait until it detects a dial tone (<i>Detect Dial Tone</i>).</p>\n"
        ) +
        # Modem dialog help 5/5
        _(
          "<p>Press <b>Details</b> to configure the baud rate and the modem \ninitialization strings.</p>"
        )

      # DIALOG CONTENTS

      _DeviceTerm = nil

      if detected == true
        _DeviceTerm = Left(
          HBox(
            # Label text
            Label(_("Modem Device:")),
            HSpacing(0.5),
            Label(Opt(:outputField), Modem.Device)
          )
        )
      else
        # ComboBox label
        _DeviceTerm = ComboBox(
          Id(:Device),
          Opt(:hstretch, :editable),
          _("Modem De&vice"),
          devices
        )
      end

      contents = HBox(
        HSpacing(6),
        VBox(
          VSpacing(0.2),
          _DeviceTerm,
          VSpacing(1),
          HBox(
            #`TextEntry(`id(`ModemName), _("&Modem name"), name),
            # TextEntry label
            TextEntry(
              Id(:DialPrefix),
              _("Dial Prefi&x (if needed)"),
              Modem.DialPrefix
            )
          ),
          VSpacing(0.8),
          HBox(
            # Frame label
            Frame(
              _("Dial Mode"),
              VBox(
                VSpacing(0.3),
                HBox(
                  HSpacing(0.3),
                  RadioButtonGroup(
                    Id(:DialMode),
                    VBox(
                      # RadioButton label
                      Left(
                        RadioButton(
                          Id(:Tone),
                          _("&Tone Dialing"),
                          !Modem.PulseDial
                        )
                      ),
                      # RadioButton label
                      Left(
                        RadioButton(
                          Id(:Pulse),
                          _("&Pulse Dialing"),
                          Modem.PulseDial
                        )
                      )
                    )
                  ),
                  HSpacing(0.3)
                ),
                VSpacing(0.3)
              )
            ),
            HSpacing(1),
            # Frame label
            Frame(
              _("Special Settings"),
              HBox(
                HSpacing(0.3),
                VBox(
                  VSpacing(0.3),
                  # Checkbox label
                  Left(CheckBox(Id(:Speaker), _("&Speaker On"), Modem.Speaker)),
                  # Checkbox label
                  Left(
                    CheckBox(
                      Id(:CarrierDetect),
                      _("D&etect Dial Tone"),
                      Modem.Carrier
                    )
                  ),
                  VSpacing(0.3)
                ),
                HSpacing(0.3)
              )
            )
          ),
          VSpacing(1),
          # Button label
          PushButton(Id(:Details), _("&Details")),
          VSpacing(0.2)
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

      # MAIN CYCLE

      ret = nil
      while true
        ret = Convert.to_symbol(UI.UserInput)

        # abort?
        if ret == :abort || ret == :cancel
          if ReallyAbort()
            break
          else
            next
          end
        # back
        elsif ret == :back
          break
        # next
        elsif ret == :next || ret == :Details
          # check_*
          break
        else
          Builtins.y2error("unexpected retcode: %1", ret)
          next
        end
      end

      # UPDATE VARIABLES

      if ret == :next || ret == :Details
        Modem.DialPrefix = Convert.to_string(
          UI.QueryWidget(Id(:DialPrefix), :Value)
        )

        if detected != true
          Modem.Device = Convert.to_string(UI.QueryWidget(Id(:Device), :Value))
        end

        Modem.PulseDial = Convert.to_boolean(UI.QueryWidget(Id(:Pulse), :Value))
        Modem.Speaker = Convert.to_boolean(UI.QueryWidget(Id(:Speaker), :Value))
        Modem.Carrier = Convert.to_boolean(
          UI.QueryWidget(Id(:CarrierDetect), :Value)
        )
      end

      ret
    end

    # Modem details dialog
    # @return dialog result
    def ModemDetailsDialog
      # PREPARE VARIABLES
      _BaudRate = Modem.BaudRate
      _Init1 = Modem.Init1
      _Init2 = Modem.Init2
      _Init3 = Modem.Init3
      usercontrol = Modem.usercontrol
      _DialPrefixRx = Modem.DialPrefixRx


      widgets = CWM.CreateWidgets(
        ["USERCONTROL", "DIALPREFIXREGEX"],
        @widget_descr
      )

      # DIALOG TEXTS

      # Modem datails dialog caption
      caption = _("Modem Parameter Details")

      # Modem datails dialog help 1/2
      helptext = Ops.add(
        _(
          "<p><b>Baud Rate</b> is a transmission speed that tells\nhow many bits per second your computer communicates with your modem.</p>\n"
        ) +
          # Modem datails dialog help 2/2
          _(
            "<p>All the relevant information about <b>Init Strings</b>\nshould be in your modem manual.</p>\n"
          ),
        CWM.MergeHelps(widgets)
      )


      # DIALOG CONTENTS

      _BaudRates = Builtins.maplist(
        Builtins.toset(
          [1200, 2400, 4800, 9600, 19200, 38400, 57600, 115200, _BaudRate]
        )
      ) do |e|
        Item(
          Id(Builtins.sformat("%1", e)),
          Builtins.sformat("%1", e),
          e == _BaudRate
        )
      end

      contents = HBox(
        HSpacing(6),
        VBox(
          # Combo box label
          ComboBox(
            Id(:Baud),
            Opt(:hstretch, :editable),
            _("B&aud Rate"),
            _BaudRates
          ),
          VSpacing(0.5),
          # Frame label
          Frame(
            _("Modem Initialization Strings"),
            HBox(
              HSpacing(0.2),
              VBox(
                # Text entry label
                TextEntry(Id(:Init1), _("Init &1"), _Init1),
                VSpacing(0.5),
                # Text entry label
                TextEntry(Id(:Init2), _("Init &2"), _Init2),
                VSpacing(0.5),
                # Text entry label
                TextEntry(Id(:Init3), _("Init &3"), _Init3),
                VSpacing(0.4)
              ),
              HSpacing(0.2)
            )
          ),
          VSpacing(1),
          # 0 is index to CreateWidgets... ugly
          Left(Ops.get_term(widgets, [0, "widget"], Empty())),
          VSpacing(0.5),
          Left(Ops.get_term(widgets, [1, "widget"], Empty())),
          VSpacing(1)
        ),
        HSpacing(6)
      )


      # DIALOG PREPARE

      Wizard.SetContentsButtons(
        caption,
        contents,
        helptext,
        Label.BackButton,
        Label.OKButton
      )
      UI.ChangeWidget(Id("USERCONTROL"), :Value, usercontrol)
      UI.ChangeWidget(Id("DIALPREFIXREGEX"), :Value, _DialPrefixRx)

      # MAIN CYCLE

      ret = nil
      while true
        usercontrol = Convert.to_boolean(
          UI.QueryWidget(Id("USERCONTROL"), :Value)
        )
        UI.ChangeWidget(Id("DIALPREFIXREGEX"), :Enabled, usercontrol)

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
        elsif ret == :next
          # check_*
          break
        elsif ret != "USERCONTROL"
          Builtins.y2error("unexpected retcode: %1", ret)
          next
        end
      end

      # UPDATE VARIABLES

      if ret == :next
        Modem.BaudRate = Builtins.tointeger(UI.QueryWidget(Id(:Baud), :Value))
        Modem.Init1 = Convert.to_string(UI.QueryWidget(Id(:Init1), :Value))
        Modem.Init2 = Convert.to_string(UI.QueryWidget(Id(:Init2), :Value))
        Modem.Init3 = Convert.to_string(UI.QueryWidget(Id(:Init3), :Value))
        Modem.usercontrol = usercontrol
        if usercontrol
          Modem.DialPrefixRx = Convert.to_string(
            UI.QueryWidget(Id("DIALPREFIXREGEX"), :Value)
          )
        end
      end

      Convert.to_symbol(ret)
    end
  end
end
