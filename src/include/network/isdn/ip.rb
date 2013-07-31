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
# File:	include/network/isdn/ip.ycp
# Package:	Configuration of network
# Summary:	ISDN configuration IP addresses dialog
# Authors:	Michal Svec <msvec@suse.cz>
#		Karsten Keil <kkeil@suse.cz>
#
module Yast
  module NetworkIsdnIpInclude
    def initialize_network_isdn_ip(include_target)
      Yast.import "UI"

      textdomain "network"

      Yast.import "IP"
      Yast.import "ISDN"
      Yast.import "Label"
      Yast.import "Popup"
      Yast.import "Wizard"
    end

    # Dialog for ISDN IP settings
    # @return [Object] user input
    def IPDialog
      # DIALOG TEXTS

      # title for ISDN IP address dialog
      caption = _("ISDN IP Address Settings")

      # FIXME: help texts, contents

      helptext =
        # help text 1/3
        _(
          "<p>Enter the IP addresses if you received a fixed IP address\nfrom your provider for syncppp or you use raw IP.</p>\n"
        )

      helptext = Ops.add(
        helptext,
        # help text 2/3
        _(
          "<p>Check <b>Dynamic IP Address</b> if your provider\n" +
            "assigns you one temporary address per connection. In this case, the\n" +
            "outgoing address is unknown until the moment the link is established.\n" +
            "This is the default with most providers.\n" +
            "</p>\n"
        )
      )

      helptext = Ops.add(
        helptext,
        # help text 3/3
        _(
          "<p>Check <b>Default Route</b> to use this interface as the\n" +
            "default route. Only one interface can be the default\n" +
            "route.</p>\n"
        )
      )

      # PREPARE VARIABLES
      _Local_IP = Ops.get_string(ISDN.interface, "IPADDR", "192.168.99.1")
      _Remote_IP = Ops.get_string(ISDN.interface, "PTPADDR", "192.168.99.2")
      syncppp = Ops.get_string(ISDN.interface, "PROTOCOL", "syncppp") == "syncppp"
      defaultroute = Ops.get_string(ISDN.interface, "DEFAULTROUTE", "yes") == "yes"
      dynip = Ops.get_string(ISDN.interface, "DYNAMICIP", "yes") == "yes"

      # DIALOG CONTENTS

      contents = nil

      if syncppp
        contents = HSquash(
          VBox(
            # Frame title for ISDN IP address settings
            Frame(
              _("IP Address Settings"),
              HBox(
                HSpacing(),
                VBox(
                  VSpacing(),
                  # CheckBox label
                  Left(
                    CheckBox(
                      Id(:dynip),
                      Opt(:notify),
                      _("&Dynamic IP Address"),
                      dynip
                    )
                  ),
                  VSpacing(),
                  # TextEntry label
                  Left(
                    TextEntry(
                      Id(:IP_local),
                      _("&Local IP Address of Your Machine"),
                      _Local_IP
                    )
                  ),
                  # TextEntry label
                  Left(
                    TextEntry(
                      Id(:IP_remote),
                      _("Re&mote IP Address"),
                      _Remote_IP
                    )
                  ),
                  VSpacing()
                ),
                HSpacing()
              )
            ),
            VSpacing(),
            # CheckBox label
            Left(CheckBox(Id(:defaultroute), _("D&efault Route"), defaultroute))
          )
        )
      else
        contents =
          #`HSquash(
          VBox(
            # Frame title for ISDN IP address settings
            Frame(
              _("IP Address Settings"),
              HBox(
                HSpacing(),
                VBox(
                  VSpacing(),
                  # TextEntry label
                  Left(
                    TextEntry(
                      Id(:IP_local),
                      _("&Local IP Address of Your Machine"),
                      _Local_IP
                    )
                  ),
                  # TextEntry label
                  Left(
                    TextEntry(
                      Id(:IP_remote),
                      _("Re&mote IP Address"),
                      _Remote_IP
                    )
                  ),
                  VSpacing()
                ),
                HSpacing()
              )
            ), #)
            VSpacing(),
            # CheckBox label
            Left(CheckBox(Id(:defaultroute), _("D&efault Route"), defaultroute))
          )
      end

      Builtins.y2debug("contents=%1", contents)

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
        ret = UI.UserInput

        # abort?
        if ret == :abort || ret == :cancel
          if Popup.ReallyAbort(true)
            break
          else
            next
          end
        elsif ret == :dynip
          dip = Convert.to_boolean(UI.QueryWidget(Id(:dynip), :Value))
          next
        # back
        elsif ret == :back
          break
        # next
        elsif ret == :next
          _Local_IP = Convert.to_string(UI.QueryWidget(Id(:IP_local), :Value))
          _Remote_IP = Convert.to_string(UI.QueryWidget(Id(:IP_remote), :Value))
          defaultroute = Convert.to_boolean(
            UI.QueryWidget(Id(:defaultroute), :Value)
          )

          if syncppp
            dynip = Convert.to_boolean(UI.QueryWidget(Id(:dynip), :Value))
          end

          if (!syncppp || !dynip) &&
              (!IP.Check4(_Local_IP) || !IP.Check4(_Remote_IP))
            # Popup::Message if entries are incorrect
            Popup.Message(
              _("Local and remote IP addresses must be completed correctly.")
            )
            next
          end
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
            "IPADDR"       => _Local_IP,
            "PTPADDR"      => _Remote_IP,
            "DEFAULTROUTE" => defaultroute ? "yes" : "no"
          }
        )
        if syncppp
          ISDN.interface = Builtins.union(
            ISDN.interface,
            { "DYNAMICIP" => dynip ? "yes" : "no" }
          )
        end
      end
      deep_copy(ret)
    end
  end
end
