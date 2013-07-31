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
# File:	clients/network.ycp
# Package:	Network configuration
# Summary:	Main network client
# Authors:	Michal Svec <msvec@suse.cz>
#
#
# Main file for the network configuration.
# Uses all other files.
module Yast
  class NetworkClient < Client
    def main
      Yast.import "UI"

      textdomain "network"

      # The main ()
      Builtins.y2milestone("----------------------------------------")
      Builtins.y2milestone("Network module started")

      Yast.import "Label"
      Yast.import "Wizard"
      Yast.import "CommandLine"

      # is this proposal or not?
      @propose = false
      @args = WFM.Args
      if Ops.greater_than(Builtins.size(@args), 0)
        if Ops.is_path?(WFM.Args(0)) && WFM.Args(0) == path(".propose")
          Builtins.y2milestone("Using PROPOSE mode")
          @propose = true
        end
      end

      @cmdline_description = {
        "id"         => "network",
        # translators: command line help for network module
        "help"       => _(
          "Configuration of network.\n" +
            "This is only a delegator to network sub-modules.\n" +
            "You can run these network modules:\n" +
            "\n" +
            "lan\t"
        ) +
          _("Network Card") + "\nisdn\t" +
          _("ISDN Card") + "\nmodem\t" +
          _("Modem") + "\ndsl\t" +
          _("DSL Connection") + "\n",
        "guihandler" => fun_ref(method(:startDialog), "any ()"),
        "initialize" => fun_ref(method(:initNet), "void ()"),
        "finish"     => fun_ref(method(:finishNet), "void ()"),
        # 	"actions" : $[
        # 	   "run" : $[
        # 		"handler" : runHandler,
        # 		"help" : _("Run network modules")
        # 		    ],
        # 		],
        "options"    => {},
        "mapping" =>
          #		"run" : [  ],
          {}
      }


      # main ui function
      @ret = nil

      if @propose
        @ret = startDialog
      else
        #	y2internal("%1", CommandLine::Parse(cmdline_description));
        @ret = CommandLine.Run(@cmdline_description)
      end
      Builtins.y2debug("ret=%1", @ret)


      :next 

      # EOF
    end

    def startDialog
      # Network dialog caption
      caption = _("Network Configuration")

      # Network dialog help
      help = _(
        "<p>Choose one of the available network modules to configure\n the corresponding devices and press <b>Launch</b>.</p>"
      )

      # Network dialog contents
      contents = HBox(
        HSpacing(8),
        # Frame label
        #`Frame(_("Available network modules:"), `HBox(`HSpacing(2),
        VBox(
          VSpacing(3),
          # Selection box label
          SelectionBox(
            Id(:modules),
            Opt(:notify),
            _("&Available Network Modules:"),
            [
              # Selection box item
              Item(Id("lan"), _("Network Card"), true),
              # Selection box item
              Item(Id("isdn"), _("ISDN Card")),
              # Selection box item
              Item(Id("modem"), _("Modem")),
              # Selection box item
              Item(Id("dsl"), _("DSL Connection"))
            ]
          ),
          VSpacing(3)
        ),
        #`HSpacing(2))),
        HSpacing(8)
      )

      Wizard.CreateDialog
      Wizard.SetDesktopTitleAndIcon("network")
      Wizard.SetContentsButtons(
        caption,
        contents,
        help,
        Label.BackButton, # Label::FinishButton()
        _("&Launch")
      )

      UI.SetFocus(Id(:modules))

      ret = nil
      while true
        ret = UI.UserInput

        # abort?
        if ret == :abort || ret == :cancel
          # if(ReallyAbort()) break;
          # else continue;
          break
        # next
        elsif ret == :next || ret == :modules
          # check_*
          ret = :next
          break
        # back
        elsif ret == :back
          break
        else
          Builtins.y2error("unexpected retcode: %1", ret)
          next
        end
      end

      launch = "lan"
      if ret == :next
        launch = Convert.to_string(UI.QueryWidget(Id(:modules), :CurrentItem))
        Builtins.y2debug("launch=%1", launch)
      end

      UI.CloseDialog

      # Finish
      Builtins.y2milestone("Network module finished")
      Builtins.y2milestone("----------------------------------------")

      if ret == :next
        return WFM.CallFunction(launch, WFM.Args)
      else
        return :back
      end
    end

    def runHandler(options)
      options = deep_copy(options)
      # CommandLine::Print(_("bla"));
      true
    end

    def initNet
      nil
    end

    def finishNet
      nil
    end
  end
end

Yast::NetworkClient.new.main
