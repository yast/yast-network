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
# File:	include/network/provider/details.ycp
# Package:	Network configuration
# Summary:	Provider details configuration dialogs
# Authors:	Michal Svec <msvec@suse.cz>
#
module Yast
  module NetworkProviderDetailsInclude
    def initialize_network_provider_details(include_target)
      Yast.import "UI"

      textdomain "network"

      Yast.import "IP"
      Yast.import "Label"
      Yast.import "Popup"
      Yast.import "Provider"
      Yast.import "Wizard"

      Yast.include include_target, "network/routines.rb"
    end

    # IP details dialog
    # @return dialog result
    def IPDetailsDialog
      # PREPARE VARIABLES

      type = Provider.Type

      # FIXME: help texts, contents
      _Local_IP = Ops.get_string(Provider.Current, "IPADDR", "")
      _Remote_IP = Ops.get_string(Provider.Current, "REMOTE_IPADDR", "")

      encap = Ops.get_string(Provider.Current, "ENCAP", "syncppp")
      defaultroute = Ops.get_string(Provider.Current, "DEFAULTROUTE", "yes") == "yes"
      modifyip = Ops.get_string(Provider.Current, "MODIFYIP", "yes") == "yes"

      # DIALOG TEXTS and  DIALOG CONTENTS

      # IP details dialog caption
      caption = _("IP Address Settings")

      # IP details dialog help 1/3
      helptext = _(
        "<p>Enter the IP addresses if you received fixed\nIP addresses from your provider.</p>"
      )

      # IP details dialog help 2/3
      helptext = Ops.add(
        helptext,
        _(
          "<p>Check <b>Dynamic IP Address</b>\n" +
            "if your provider assigns one temporary address per connection. In this case,\n" +
            "the outgoing address is unknown until the moment the link is established.\n" +
            "This is the default with most providers.</p>"
        )
      )

      if false # FIXME: not needed
        if encap != "rawip"
          helptext = Ops.add(
            helptext,
            # IP details dialog help 3/3
            _(
              "<p>Check <b>Use Peer DNS</b> to change\n" +
                "your domain name servers after the connection is made. This replaces your static\n" +
                "DNS configuration with the obtained DNS server IP addresses. Today, almost all\n" +
                "providers support <b>Use Peer DNS</b>.</p>\n"
            )
          )
        end
      end

      if type == "isdn"
        helptext = Ops.add(
          helptext,
          # help text 1/3
          _(
            "<p>If callback mode is off,  calls  are handled normally without special \nprocessing.</p>"
          )
        )

        helptext = Ops.add(
          helptext,
          # helptext text 2/3
          _(
            "<p>If callback mode is server, after getting an incoming call, a callback \nis triggered.</p>"
          )
        )

        helptext = Ops.add(
          helptext,
          # helptext text 3/3
          _(
            "If callback mode is client, the local system does the initial call then \nwaits for callback from the remote machine.\n"
          )
        )
      end

      # IP details dialog help 4/4
      helptext = Ops.add(
        helptext,
        _(
          "<p>Check <b>Default Route</b> to set the default\n" +
            "route for this provider. This is most likely correct unless you want to reach\n" +
            "single machines or subnetworks through this provider.</p>"
        )
      )

      contents = nil

      if encap == "rawip"
        contents =
          #`HSquash(
          VBox(
            # Frame label
            Frame(
              _("IP Address Settings"),
              HBox(
                HSpacing(),
                VBox(
                  VSpacing(),
                  # Text entry label
                  Left(
                    TextEntry(
                      Id(:IP_local),
                      _("&Local IP Address of Your Machine"),
                      _Local_IP
                    )
                  ),
                  # Text entry label
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
            # Checkbox label
            Left(CheckBox(Id(:defaultroute), _("D&efault Route"), defaultroute))
          )
      else
        contents = HSquash(
          VBox(
            # Frame label
            Frame(
              _("IP Address Settings"),
              HBox(
                HSpacing(),
                VBox(
                  VSpacing(),
                  # Checkbox label
                  Left(
                    CheckBox(
                      Id(:modifyip),
                      Opt(:notify),
                      _("&Dynamic IP Address"),
                      modifyip
                    )
                  ),
                  VSpacing(),
                  # Text entry label
                  Left(
                    TextEntry(
                      Id(:IP_local),
                      _("&Local IP Address of Your Machine"),
                      _Local_IP
                    )
                  ),
                  # Text entry label
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
            # Checkbox label
            Left(CheckBox(Id(:defaultroute), _("D&efault Route"), defaultroute))
          )
        )
      end

      contents = HSquash(VBox(contents, VSpacing(0.5))) if type == "isdn"

      Builtins.y2debug("type=%1", type)
      Builtins.y2debug("contents=%1", contents)

      # DIALOG PREPARE
      Wizard.SetContentsButtons(
        caption,
        contents,
        helptext,
        Label.BackButton,
        Label.OKButton
      )

      if modifyip && encap != "rawip"
        UI.ChangeWidget(Id(:IP_local), :Enabled, false)
        UI.ChangeWidget(Id(:IP_remote), :Enabled, false)
      end

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
        elsif ret == :modifyip
          dip = Convert.to_boolean(UI.QueryWidget(Id(:modifyip), :Value))
          UI.ChangeWidget(Id(:IP_local), :Enabled, !dip)
          UI.ChangeWidget(Id(:IP_remote), :Enabled, !dip)
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

          if encap != "rawip"
            modifyip = Convert.to_boolean(UI.QueryWidget(Id(:modifyip), :Value))
          end

          if (encap == "rawip" || !modifyip) &&
              (!IP.Check4(_Local_IP) || !IP.Check4(_Remote_IP))
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
        Provider.Current = Builtins.union(
          Provider.Current,
          {
            "IPADDR"        => _Local_IP,
            "REMOTE_IPADDR" => _Remote_IP,
            "DEFAULTROUTE"  => defaultroute ? "yes" : "no",
            "MODIFYIP"      => modifyip ? "yes" : "no"
          }
        )
      end
      deep_copy(ret)
    end
  end
end
