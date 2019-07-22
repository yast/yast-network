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
# File:	include/network/lan/hardware.ycp
# Package:	Network configuration
# Summary:	Hardware dialogs
# Authors:	Michal Svec <msvec@suse.cz>
#

include Yast::UIShortcuts

module Yast
  module NetworkLanHardwareInclude
    def initialize_network_lan_hardware(include_target)
      Yast.import "UI"

      textdomain "network"

      Yast.import "Arch"
      Yast.import "CWM"
      Yast.import "Label"
      Yast.import "Lan"
      Yast.import "NetworkInterfaces"
      Yast.import "Popup"
      Yast.import "Wizard"
      Yast.import "LanItems"
      Yast.include include_target, "network/routines.rb"
      Yast.include include_target, "network/lan/cards.rb"

      @hardware = nil
    end

    # Dynamic initialization of help text.
    #
    # @return content of the help
    def initHelp
      if Arch.s390
        # overwrite help
        # Manual dialog help 5/4
        hw_help = _(
          "<p>Here, set up your networking device. The values will be\nwritten to <i>/etc/modprobe.conf</i> or <i>/etc/chandev.conf</i>.</p>\n"
        ) +
          # Manual dialog help 6/4
          _(
            "<p>Options for the module should be written in the format specified\nin the <b>IBM Device Drivers and Installation Commands</b> manual.</p>"
          )
      end

      hw_help
    end

    # S/390 devices configuration dialog
    # @return dialog result
    def S390Dialog(builder:)
      # S/390 dialog caption
      caption = _("S/390 Network Card Configuration")

      drvtype = DriverType(builder.type.short_name)

      helptext = ""
      contents = Empty()

      if Builtins.contains(["qeth", "hsi"], builder.type.short_name)
        # CHANIDS
        tmp_list = Builtins.splitstring(LanItems.qeth_chanids, " ")
        chanids_map = {
          "read"    => Ops.get(tmp_list, 0, ""),
          "write"   => Ops.get(tmp_list, 1, ""),
          "control" => Ops.get(tmp_list, 2, "")
        }
        contents = HBox(
          HSpacing(6),
          # Frame label
          Frame(
            _("S/390 Device Settings"),
            HBox(
              HSpacing(2),
              VBox(
                VSpacing(1),
                ComboBox(
                  Id(:qeth_portnumber),
                  _("Port Number"),
                  [Item(Id("0"), "0", true), Item(Id("1"), "1")]
                ),
                VSpacing(1),
                # TextEntry label
                InputField(
                  Id(:qeth_options),
                  Opt(:hstretch),
                  Label.Options,
                  LanItems.qeth_options
                ),
                VSpacing(1),
                # CheckBox label
                Left(CheckBox(Id(:ipa_takeover), _("&Enable IPA Takeover"))),
                VSpacing(1),
                # CheckBox label
                Left(
                  CheckBox(
                    Id(:qeth_layer2),
                    Opt(:notify),
                    _("Enable &Layer 2 Support")
                  )
                ),
                # TextEntry label
                InputField(
                  Id(:qeth_macaddress),
                  Opt(:hstretch),
                  _("Layer2 &MAC Address"),
                  LanItems.qeth_macaddress
                ),
                VSpacing(1),
                HBox(
                  InputField(
                    Id(:qeth_chan_read),
                    Opt(:hstretch),
                    _("Read Channel"),
                    Ops.get_string(chanids_map, "read", "")
                  ),
                  InputField(
                    Id(:qeth_chan_write),
                    Opt(:hstretch),
                    _("Write Channel"),
                    Ops.get_string(chanids_map, "write", "")
                  ),
                  InputField(
                    Id(:qeth_chan_control),
                    Opt(:hstretch),
                    _("Control Channel"),
                    Ops.get_string(chanids_map, "control", "")
                  )
                )
              ),
              HSpacing(2)
            )
          ),
          HSpacing(6)
        )
        # S/390 dialog help: QETH Options
        helptext = _(
            "<p>Enter any additional <b>Options</b> for this interface (separated by spaces).</p>"
          ) +
          _(
            "<p>Select <b>Enable IPA Takeover</b> if IP address takeover should be enabled for this interface.</p>"
          ) +
          _(
            "<p>Select <b>Enable Layer 2 Support</b> if this card has been configured with layer 2 support.</p>"
          ) +
          _(
            "<p>Enter the <b>Layer 2 MAC Address</b> if this card has been configured with layer 2 support.</p>"
          )
      end

      if drvtype == "lcs"
        tmp_list = Builtins.splitstring(LanItems.qeth_chanids, " ")
        chanids_map = {
          "read"  => Ops.get(tmp_list, 0, ""),
          "write" => Ops.get(tmp_list, 1, "")
        }
        contents = HBox(
          HSpacing(6),
          # Frame label
          Frame(
            _("S/390 Device Settings"),
            HBox(
              HSpacing(2),
              VBox(
                VSpacing(1),
                # TextEntry label
                InputField(
                  Id(:chan_mode),
                  Opt(:hstretch),
                  _("&Port Number"),
                  LanItems.chan_mode
                ),
                VSpacing(1),
                # TextEntry label
                InputField(
                  Id(:lcs_timeout),
                  Opt(:hstretch),
                  _("&LANCMD Time-Out"),
                  LanItems.lcs_timeout
                ),
                VSpacing(1),
                HBox(
                  InputField(
                    Id(:qeth_chan_read),
                    Opt(:hstretch),
                    _("Read Channel"),
                    Ops.get_string(chanids_map, "read", "")
                  ),
                  InputField(
                    Id(:qeth_chan_write),
                    Opt(:hstretch),
                    _("Write Channel"),
                    Ops.get_string(chanids_map, "write", "")
                  )
                )
              ),
              HSpacing(2)
            )
          ),
          HSpacing(6)
        )
        # S/390 dialog help: LCS
        helptext = _("<p>Choose the <b>Port Number</b> for this interface.</p>") +
          _("<p>Specify the <b>LANCMD Time-Out</b> for this interface.</p>")
      end

      ctcitems = [
        # ComboBox item: CTC device protocol
        Item(Id("0"), _("Compatibility Mode")),
        # ComboBox item: CTC device protocol
        Item(Id("1"), _("Extended Mode")),
        # ComboBox item: CTC device protocol
        Item(Id("2"), _("CTC-Based tty (Linux to Linux Connections)")),
        # ComboBox item: CTC device protocol
        Item(Id("3"), _("Compatibility Mode with OS/390 and z/OS"))
      ]

      if drvtype == "ctc"
        tmp_list = Builtins.splitstring(LanItems.qeth_chanids, " ")
        chanids_map = {
          "read"  => Ops.get(tmp_list, 0, ""),
          "write" => Ops.get(tmp_list, 1, "")
        }
        contents = HBox(
          HSpacing(6),
          # Frame label
          Frame(
            _("S/390 Device Settings"),
            HBox(
              HSpacing(2),
              VBox(
                VSpacing(1),
                # TextEntry label
                ComboBox(Id(:chan_mode), _("&Protocol"), ctcitems),
                VSpacing(1),
                HBox(
                  InputField(
                    Id(:qeth_chan_read),
                    Opt(:hstretch),
                    _("Read Channel"),
                    Ops.get_string(chanids_map, "read", "")
                  ),
                  InputField(
                    Id(:qeth_chan_write),
                    Opt(:hstretch),
                    _("Write Channel"),
                    Ops.get_string(chanids_map, "write", "")
                  )
                )
              ),
              HSpacing(2)
            )
          ),
          HSpacing(6)
        )
        # S/390 dialog help: CTC
        helptext = _("<p>Choose the <b>Protocol</b> for this interface.</p>")
      end

      if drvtype == "iucv"
        contents = HBox(
          HSpacing(6),
          # Frame label
          Frame(
            _("S/390 Device Settings"),
            HBox(
              HSpacing(2),
              VBox(
                VSpacing(1),
                # TextEntry label, #42789
                InputField(
                  Id(:iucv_user),
                  Opt(:hstretch),
                  _("&Peer Name"),
                  LanItems.iucv_user
                ),
                VSpacing(1)
              ),
              HSpacing(2)
            )
          ),
          HSpacing(6)
        )
        # S/390 dialog help: IUCV, #42789
        helptext = _(
          "<p>Enter the name of the IUCV peer,\nfor example, the z/VM user name with which to connect (case-sensitive).</p>\n"
        )
      end

      Wizard.SetContentsButtons(
        caption,
        contents,
        helptext,
        Label.BackButton,
        Label.NextButton
      )

      if drvtype == "ctc"
        UI.ChangeWidget(Id(:chan_mode), :Value, LanItems.chan_mode)
      end

      if drvtype == "lcs"
        UI.ChangeWidget(Id(:chan_mode), :Value, LanItems.chan_mode)
        UI.ChangeWidget(Id(:lcs_timeout), :Value, LanItems.lcs_timeout)
      end

      if drvtype == "qeth"
        UI.ChangeWidget(Id(:ipa_takeover), :Value, LanItems.ipa_takeover)
        UI.ChangeWidget(Id(:qeth_layer2), :Value, LanItems.qeth_layer2)
        UI.ChangeWidget(
          Id(:qeth_macaddress),
          :ValidChars,
          ":0123456789abcdefABCDEF"
        )
      end

      id = case builder.type.short_name
      when "hsi"  then :qeth_options
      when "qeth" then :qeth_options
      when "iucv" then :iucv_user
      else             :chan_mode
      end
      UI.SetFocus(Id(id))

      ret = nil
      loop do
        if drvtype == "qeth"
          mac_enabled = Convert.to_boolean(
            UI.QueryWidget(Id(:qeth_layer2), :Value)
          )
          UI.ChangeWidget(Id(:qeth_macaddress), :Enabled, mac_enabled)
        end

        ret = UI.UserInput

        case ret
        when :abort, :cancel
          ReallyAbort() ? break : next
        when :back
          break
        when :next
          if builder.type.short_name == "iucv"
            LanItems.device = Ops.add(
              "id-",
              Convert.to_string(UI.QueryWidget(Id(:iucv_user), :Value))
            )
            LanItems.iucv_user = Convert.to_string(
              UI.QueryWidget(Id(:iucv_user), :Value)
            )
          end

          if builder.type.short_name == "ctc"
            LanItems.chan_mode = Convert.to_string(
              UI.QueryWidget(Id(:chan_mode), :Value)
            )
          end
          if builder.type.short_name == "lcs"
            LanItems.lcs_timeout = Convert.to_string(
              UI.QueryWidget(Id(:lcs_timeout), :Value)
            )
            LanItems.chan_mode = Convert.to_string(
              UI.QueryWidget(Id(:chan_mode), :Value)
            )
          end
          if builder.type.short_name == "qeth" || builder.type.short_name == "hsi"
            LanItems.qeth_options = Convert.to_string(
              UI.QueryWidget(Id(:qeth_options), :Value)
            )
            LanItems.ipa_takeover = Convert.to_boolean(
              UI.QueryWidget(Id(:ipa_takeover), :Value)
            )
            LanItems.qeth_layer2 = Convert.to_boolean(
              UI.QueryWidget(Id(:qeth_layer2), :Value)
            )
            LanItems.qeth_macaddress = Convert.to_string(
              UI.QueryWidget(Id(:qeth_macaddress), :Value)
            )
            LanItems.qeth_portnumber = Convert.to_string(
              UI.QueryWidget(Id(:qeth_portnumber), :Value)
            )
            )
          end
          read = Convert.to_string(UI.QueryWidget(Id(:qeth_chan_read), :Value))
          write = Convert.to_string(
            UI.QueryWidget(Id(:qeth_chan_write), :Value)
          )
          control = Convert.to_string(
            UI.QueryWidget(Id(:qeth_chan_control), :Value)
          )
          control = "" if control.nil?
          LanItems.qeth_chanids = String.CutBlanks(
            Builtins.sformat("%1 %2 %3", read, write, control)
          )
          if LanItems.createS390Device
            builder.name = LanItems.GetCurrentName
          else
            Popup.Error(
              _(
                "An error occurred while creating device.\nSee YaST log for details."
              )
            )
            ret = nil
            next
          end
          break
        when :qeth_layer2
          next
        else
          Builtins.y2error("Unexpected return code: %1", ret)
          next
        end
      end

      deep_copy(ret)
    end
  end
end
