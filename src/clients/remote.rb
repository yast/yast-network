# encoding: utf-8

# ------------------------------------------------------------------------------
# Copyright (c) 2017 SUSE LLC
#
#
# This program is free software; you can redistribute it and/or modify it under
# the terms of version 2 of the GNU General Public License as published by the
# Free Software Foundation.
#
# This program is distributed in the hope that it will be useful, but WITHOUT
# ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS
# FOR A PARTICULAR PURPOSE. See the GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License along with
# this program; if not, contact SUSE.
#
# To contact SUSE about this file by physical or electronic mail, you may find
# current contact information at www.suse.com.
# ------------------------------------------------------------------------------
require "yast"
require "y2remote/remote"
require "y2remote/dialogs/remote"

module Yast
  class RemoteClient < Client
    include Logger
    include I18n

    def initialize
      Yast.import "UI"

      textdomain "network"

      Yast.import "Label"
      Yast.import "Wizard"
      Yast.import "Report"

      Yast.import "CommandLine"
      Yast.import "RichText"
    end

    def main
      # The main ()
      log.info("----------------------------------------")
      log.info("Remote module started")

      # Command line definition
      ret = CommandLine.Run(command_line_definition)
      log.debug("ret=#{ret}")

      # Finish
      log.info("Remote module finished")
      log.info("----------------------------------------")

      ret
    end

  private

    def remote
      @remote ||= Y2Remote::Remote.instance
    end

    def command_line_definition
      {
        # Commandline help title
        "help"       => _(
          "Remote Access Configuration"
        ),
        "id"         => "remote",
        "guihandler" => fun_ref(method(:RemoteGUI), "any()"),
        "initialize" => -> { remote.read },
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
    end

    # Main remote GUI
    def RemoteGUI
      ret = Y2Remote::Dialogs::Remote.new.run

      Wizard.CreateDialog
      Wizard.SetDesktopTitleAndIcon("remote")
      Wizard.SetNextButton(:next, Label.FinishButton)

      remote.write if ret == :next

      UI.CloseDialog

      ret
    end

    # Handler for action "list"
    # @param [Hash{String => String}] options action options
    def ListHandler(_options)
      # Command line output Headline
      summary = Ops.add(
        Ops.add(
          "\n" + _("Remote Access Configuration Summary:") + "\n\n",
          RichText.Rich2Plain(remote.summary)
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
      allow_ra == "yes" ? remote.enable! : remote.disable!

      remote.Write
    end
  end
end

Yast::RemoteClient.new.main
