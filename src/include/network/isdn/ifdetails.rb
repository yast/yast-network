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
#   include/network/isdn/ifdetails.ycp
#
# Package:
#   Configuration of network
#
# Summary:
#   ISDN interface detail dialog
#
# Authors:
#   Karsten Keil <kkeil@suse.de>
#
#
module Yast
  module NetworkIsdnIfdetailsInclude
    def initialize_network_isdn_ifdetails(include_target)
      Yast.import "UI"

      textdomain "network"

      Yast.import "ISDN"
      Yast.import "Label"
      Yast.import "Popup"
      Yast.import "Wizard"
    end

    # Dialog for ISDN interface detail settings
    # @return [Object] user input

    def IFDetailDialog
      # PREPARE VARIABLES
      remote_in = Ops.get_string(ISDN.interface, "REMOTE_IN", "")
      ipppd_opt = Ops.get_string(ISDN.interface, "IPPPD_OPTIONS", "")
      syncppp = Ops.get_string(ISDN.interface, "PROTOCOL", "syncppp") == "syncppp"
      secure = Ops.get_string(ISDN.interface, "SECURE", "on") == "on"
      cbdel = Builtins.tointeger(Ops.get_string(ISDN.interface, "CBDELAY", "2"))
      callback = Ops.get_string(ISDN.interface, "CALLBACK", "off")

      # DIALOG TEXTS

      # title of ISDN interface detail screen
      caption = _("ISDN Detail Settings")

      helptext =
        # help text 1/7
        _(
          "<p>The <b>Remote Phone Number List</b> controls which remote machines are\nallowed to connect to this interface.</p>\n"
        )

      helptext = Ops.add(
        helptext,
        # help text 2/7
        _(
          "<p>Deselect <b>Only Listed Numbers Allowed</b> \nto allow all caller IDs.</p>\n"
        )
      )

      helptext = Ops.add(
        helptext,
        # help text 3/7
        _(
          "<p>If the callback mode is <b>off</b>,  calls  are handled normally without special \nprocessing.</p>\n"
        )
      )

      helptext = Ops.add(
        helptext,
        # help text 4/7
        _(
          "<p>If the callback mode is <b>server</b>, after getting an incoming call, a callback \nis triggered.</p>\n"
        )
      )

      helptext = Ops.add(
        helptext,
        # help text 5/7
        _(
          "<p>If the callback mode is <b>client</b>, the local system does the initial call then \nwaits for callback from the remote machine.</p>\n"
        )
      )

      helptext = Ops.add(
        helptext,
        # help text 6/7
        _(
          "<p><b>Callback Delay</b> is the number of seconds between the initial call and the\n" +
            "callback (server) or the hang-up (client). It should be greater on the server than on\n" +
            "the client.</p>\n"
        )
      )

      if syncppp
        helptext = Ops.add(
          helptext,
          # help text 7/7
          _(
            "<p>In <b>Additional ipppd Options</b>, add extra options for ipppd,\nfor example, +pap +chap for the dial-in server authentication.</p>\n"
          )
        )
      end

      # DIALOG CONTENTS

      ipppd = VSpacing()
      if syncppp
        # TextEntry label
        ipppd = TextEntry(
          Id(:ipppd_opt),
          _("&Additional ipppd Options"),
          ipppd_opt
        )
      end

      cbterm =
        # Frame title
        Frame(
          _("Callback Functions"),
          VBox(
            VSpacing(0.2),
            RadioButtonGroup(
              Id(:callback),
              HBox(
                VBox(
                  # RadioButton for callback modes
                  Left(
                    RadioButton(
                      Id(:off),
                      Opt(:notify),
                      _("Callback Of&f"),
                      callback == "off"
                    )
                  ),
                  # RadioButton for callback modes
                  Left(
                    RadioButton(
                      Id(:in),
                      Opt(:notify),
                      _("Callback &Server"),
                      callback == "in"
                    )
                  ),
                  # RadioButton for callback modes
                  Left(
                    RadioButton(
                      Id(:out),
                      Opt(:notify),
                      _("Callback &Client"),
                      callback == "out"
                    )
                  )
                )
              )
            ),
            VSpacing(0.5),
            HBox(
              HSpacing(0.5),
              Left(
                HSquash(
                  # IntField label
                  IntField(Id(:cbdelay), _("Callback &Delay"), 0, 10, cbdel)
                )
              )
            ),
            VSpacing(0.2)
          )
        )

      contents = HBox(
        HSpacing(2),
        VBox(
          # TextEntry label
          TextEntry(Id(:remote_in), _("Remote &Phone Number List"), remote_in),
          # CheckBox label
          Left(CheckBox(Id(:secure), _("Only &Listed Numbers Allowed"), secure)),
          VSpacing(0.5),
          cbterm,
          VSpacing(0.5),
          ipppd
        ),
        HSpacing(2)
      )

      # DIALOG PREPARE
      Wizard.SetContentsButtons(
        caption,
        contents,
        helptext,
        Label.BackButton,
        Label.OKButton
      )

      UI.ChangeWidget(Id(:cbdelay), :Enabled, false) if callback == "off"

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
        elsif ret == :off
          callback = "off"
          UI.ChangeWidget(Id(:cbdelay), :Enabled, false)
        elsif ret == :in
          callback = "in"
          UI.ChangeWidget(Id(:cbdelay), :Enabled, true)
        elsif ret == :out
          callback = "out"
          UI.ChangeWidget(Id(:cbdelay), :Enabled, true)
        elsif ret == :next
          remote_in = Convert.to_string(UI.QueryWidget(Id(:remote_in), :Value))
          secure = Convert.to_boolean(UI.QueryWidget(Id(:secure), :Value))
          #	    callback = UI::QueryWidget(`id(`callback), `CurrentButton);
          cbdel = Convert.to_integer(UI.QueryWidget(Id(:cbdelay), :Value))
          if syncppp
            ipppd_opt = Convert.to_string(
              UI.QueryWidget(Id(:ipppd_opt), :Value)
            )
          end
          # check_*
          break
        else
          Builtins.y2error("unexpected retcode: %1", ret)
          next
        end
      end

      # UPDATE VARIABLES
      if ret == :next
        ISDN.interface = Builtins.union(
          ISDN.interface,
          {
            "REMOTE_IN" => remote_in,
            "SECURE"    => secure ? "on" : "off",
            "CALLBACK"  => callback,
            "CBDELAY"   => Builtins.sformat("%1", cbdel)
          }
        )
        if syncppp
          ISDN.interface = Builtins.union(
            ISDN.interface,
            { "IPPPD_OPTIONS" => ipppd_opt }
          )
        end
      end

      deep_copy(ret)
    end
  end
end
