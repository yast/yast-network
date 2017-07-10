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
# File:	clients/remote.ycp
# Package:	Network configuration
# Summary:	Remote Administration
# Authors:	Arvin Schnell <arvin@suse.de>
#		Michal Svec <msvec@suse.cz>
#
module Yast
  class RemoteClient < Client
    def main
      Yast.import "UI"

      textdomain "network"

      # The main ()
      Builtins.y2milestone("----------------------------------------")
      Builtins.y2milestone("Remote module started")

      Yast.import "Label"
      Yast.import "Remote"
      Yast.import "Wizard"
      Yast.import "Report"

      Yast.import "CommandLine"
      Yast.import "RichText"

      Yast.include self, "network/remote/dialogs.rb"

      # Command line definition
      @cmdline = {
        # Commandline help title
        "help"       => _(
          "Remote Access Configuration"
        ),
        "id"         => "remote",
        "guihandler" => fun_ref(method(:RemoteGUI), "any ()"),
        "initialize" => fun_ref(Remote.method(:Read), "boolean ()"),
        "actions"    => {
          "list"  => {
            # Commandline command help
            "help"    => _(
              "Display configuration summary"
            ),
            "handler" => fun_ref(
              method(:ListHandler),
              "boolean (map <string, string>)"
            )
          },
          "allow" => {
            # Commandline command help
            "help"    => _("Allow remote access"),
            "handler" => fun_ref(
              method(:SetRAHandler),
              "boolean (map <string, string>)"
            ),
            "example" => ["allow set=yes", "allow set=no"]
          }
        },
        "options"    => {
          "set" => {
            # Commandline command help
            "help" => _(
              "Set 'yes' to allow or 'no' to disallow the remote administration"
            ),
            "type" => "string"
          }
        },
        "mappings"   => { "allow" => ["set"] }
      }

      @ret = CommandLine.Run(@cmdline)
      Builtins.y2debug("ret=%1", @ret)

      # Finish
      Builtins.y2milestone("Remote module finished")
      Builtins.y2milestone("----------------------------------------")
      deep_copy(@ret)

      # EOF
    end

    # Main remote GUI
    def RemoteGUI
      Remote.Read

      Wizard.CreateDialog
      Wizard.SetDesktopTitleAndIcon("remote")
      Wizard.SetNextButton(:next, Label.FinishButton)

      ret = RemoteMainDialog()
      Remote.Write if ret == :next

      UI.CloseDialog
      deep_copy(ret)
    end

    # Handler for action "list"
    # @param [Hash{String => String}] options action options
    def ListHandler(_options)
      # Command line output Headline
      summary = Ops.add(
        Ops.add(
          "\n" + _("Remote Access Configuration Summary:") + "\n\n",
          RichText.Rich2Plain(Remote.Summary)
        ),
        "\n"
      )

      Builtins.y2debug("%1", summary)
      CommandLine.Print(summary)
      true
    end

    # Handler for action "allow"
    # @param [Hash{String => String}] options action options
    def SetRAHandler(options)
      options = deep_copy(options)
      allow_ra = Builtins.tolower(Ops.get(options, "set", ""))

      if allow_ra != "yes" && allow_ra != "no"
        # Command line error message
        Report.Error(
          _(
            "Please set 'yes' to allow the remote administration\nor 'no' to disallow it."
          )
        )
        return false
      end

      Builtins.y2milestone(
        "Setting AllowRemoteAdministration to '%1'",
        allow_ra
      )
      if allow_ra == "yes"
        Remote.Enable
      else
        Remote.Disable
      end

      Remote.Write
    end
  end
end

Yast::RemoteClient.new.main
