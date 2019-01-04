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
# File:	clients/host.ycp
# Package:	Network configuration
# Summary:	Hosts client
# Authors:	Michal Svec <msvec@suse.cz>
#
#
# Main file for hosts configuration.
# Uses all other files.
module Yast
  class HostClient < Client
    def main
      Yast.import "UI"

      textdomain "network"

      # The main ()
      Builtins.y2milestone("----------------------------------------")
      Builtins.y2milestone("Host module started")

      Yast.import "Host"
      Yast.import "Label"
      Yast.import "Wizard"

      Yast.import "CommandLine"
      Yast.import "RichText"

      Yast.include self, "network/runtime.rb"
      Yast.include self, "network/services/host.rb"

      # Command line definition
      @cmdline = {
        # Commandline help title
        # configuration of hosts
        "help"       => _(
          "Host Configuration"
        ),
        "id"         => "host",
        "guihandler" => fun_ref(method(:HostGUI), "any ()"),
        "initialize" => fun_ref(Host.method(:Read), "boolean ()"),
        "finish"     => fun_ref(Host.method(:Write), "boolean ()"), # FIXME
        "actions"    => {
          "list" => {
            # Commandline command help
            "help"    => _(
              "Display configuration summary"
            ),
            "handler" => fun_ref(
              method(:ListHandler),
              "boolean (map <string, string>)"
            )
          }
        }
      }

      @ret = CommandLine.Run(@cmdline)
      Builtins.y2debug("ret=%1", @ret)

      # Finish
      Builtins.y2milestone("Host module finished")
      Builtins.y2milestone("----------------------------------------")
      deep_copy(@ret)

      # EOF
    end

    # Main hosts GUI
    def HostGUI
      Host.Read

      Wizard.CreateDialog
      Wizard.SetDesktopTitleAndIcon("host")
      Wizard.SetNextButton(:next, Label.FinishButton)

      # main ui function
      ret = HostsMainDialog(true)

      Host.Write if ret == :next && Host.GetModified

      UI.CloseDialog
    end

    # Handler for action "list"
    # @param _options [Hash{String => String}] action options
    def ListHandler(_options)
      # Command line output Headline
      # configuration of hosts
      summary = "\n" + _("Host Configuration Summary:") + "\n\n" +
        RichText.Rich2Plain(Host.Summary) + "\n"

      CommandLine.Print(summary)
      true
    end
  end
end

Yast::HostClient.new.main
