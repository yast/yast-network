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
# File:	include/network/installation/dialogs.ycp
# Package:	Network configuration
# Summary:	Configuration dialogs for installation
# Authors:	Michal Svec <msvec@suse.cz>
#		Arvin Schnell <arvin@suse.de>
#
module Yast
  module NetworkInstallationDialogsInclude
    def initialize_network_installation_dialogs(include_target)
      Yast.import "UI"

      textdomain "network"

      Yast.import "Mode"
      Yast.import "Internet"
      Yast.import "Label"
      Yast.import "NetworkInterfaces"
      Yast.import "Popup"
      Yast.import "Product"
      Yast.import "String"
      Yast.import "Wizard"
      Yast.include include_target, "network/widgets.rb"
    end

    # Ask for password if required
    # @return true on success
    def AskForPassword
      return true if Internet.askpassword.nil?

      return true if Internet.askpassword == false

      UI.NormalCursor
      UI.OpenDialog(
        VBox(
          # Heading text
          Heading(_("Enter Provider Password")),
          Password(Id(:password), Label.Password),
          HBox(
            PushButton(Id(:ok), Opt(:default), Label.OKButton),
            PushButton(Id(:cancel), Label.CancelButton)
          )
        )
      )

      UI.SetFocus(Id(:password))

      ret = UI.UserInput

      if ret == :ok
        Internet.password = Convert.to_string(
          UI.QueryWidget(Id(:password), :Value)
        )
      end

      UI.CloseDialog
      UI.BusyCursor

      ret == :ok
    end

    # Show several log files.
    # @param [Array<Hash>] logs log files
    # @param [String] logdir log files directory
    def ShowLogs(logs, logdir)
      logs = deep_copy(logs)
      logs = Builtins.sort(logs) do |x, y|
        Ops.greater_than(
          Ops.get_integer(x, :prio, 0),
          Ops.get_integer(y, :prio, 0)
        )
      end

      menunames = []
      item_counter = 0
      file_index = {}
      Builtins.maplist(logs) do |v|
        item_counter = Ops.add(item_counter, 1)
        Ops.set(file_index, item_counter, Ops.get_string(v, :filename, "none"))
        menunames = Builtins.add(
          menunames,
          Item(Id(item_counter), Ops.get_string(v, :menuname, "none"))
        )
      end

      content = VBox(
        # Heading
        Left(Heading(_("Internet Connection Test Logs:"))),
        HSpacing(70),
        HBox(
          HSpacing(1.0),
          # ComboBox label
          ComboBox(
            Id(:selector),
            Opt(:notify, :hstretch),
            _("&Select Log:"),
            menunames
          ),
          HStretch()
        ),
        HBox(VSpacing(18), HSpacing(0.5), RichText(Id(:log), ""), HSpacing(0.5)),
        PushButton(Id(:ok), Opt(:default), Label.OKButton)
      )

      UI.OpenDialog(content)

      filename = Ops.get(file_index, 1, "none")

      loop do
        # Read file and fill logview
        Builtins.y2milestone(
          "Opening file: %1",
          Ops.add(Ops.add(logdir, "/"), filename)
        )
        tmp2 = Convert.to_string(
          SCR.Read(
            path(".target.string"),
            Ops.add(Ops.add(logdir, "/"), filename)
          )
        )
        tmp2 = "file not found" if tmp2.nil?
        UI.ChangeWidget(
          Id(:log),
          :Value,
          Ops.add(Ops.add("<pre>", String.EscapeTags(tmp2)), "</pre>")
        )

        ret = UI.UserInput

        break if ret == :ok

        next unless ret == :selector
        selected_menu_item = Convert.to_integer(
          UI.QueryWidget(Id(:selector), :Value)
        )

        filename = Ops.get(file_index, selected_menu_item, "none")
      end

      UI.CloseDialog

      nil
    end
  end
end
