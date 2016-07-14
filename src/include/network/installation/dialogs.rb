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

    #  Set device from argument as default network device
    def SetDevice(dev)
      Internet.device = dev
      NetworkInterfaces.Select(Internet.device)
      Internet.type = NetworkInterfaces.FastestType(Internet.device)
      Internet.provider = Ops.get_string(
        NetworkInterfaces.Current,
        "PROVIDER",
        ""
      )

      if Internet.provider != ""
        Yast.import "Provider"
        Provider.Read
        Provider.Select(Internet.provider)
        Internet.demand = Ops.get_string(Provider.Current, "DEMAND", "no") == "yes"
        Internet.password = Ops.get_string(Provider.Current, "PASSWORD", "")
        Internet.askpassword = Ops.get_string(
          Provider.Current,
          "ASKPASSWORD",
          "no"
        ) == "yes"
        Internet.capi_adsl = Ops.get_string(
          Provider.Current,
          "PPPMODE",
          "pppoe"
        ) == "capi-adsl"
        Internet.capi_isdn = Ops.get_string(Provider.Current, "PPPMODE", "ippp") == "capi-isdn"
      end

      nil
    end

    # Connection steps dialog
    # @return dialog result
    def TestStepsDialog
      # Steps dialog caption
      caption = _("Test Internet Connection")

      # Steps dialog caption 1/2
      help = _(
        "<p>Here, validate the Internet connection just\nconfigured. The test is entirely optional.</p>"
      )

      if Product.run_you
        # Steps dialog caption 2/2
        help = Ops.add(
          help,
          _(
            "<p>A successful result enables you to run\nthe YaST Online Update.</p>"
          )
        )
      end

      # Label text (keep lines max. 65 chars long)
      label = _(
        "To validate your Internet access,\nactivate the test procedure."
      )

      labels = {
        # Label text (keep lines max. 65 chars long)
        "dsl"   => _(
          "To validate your DSL Internet access,\nactivate the test procedure."
        ),
        # Label text (keep lines max. 65 chars long)
        "isdn"  => _(
          "To validate your ISDN Internet access,\nactivate the test procedure."
        ),
        # Label text (keep lines max. 65 chars long)
        "modem" => _(
          "To validate your modem Internet access,\nactivate the test procedure."
        )
      }

      if Builtins.haskey(labels, Internet.type)
        label = Ops.get_string(labels, Internet.type, "")
      end

      items = getInternetItems

      already_up = false
      already_up = Internet.Status if !Mode.test
      current = Internet.device
      # Radiobuttons
      buttons = VBox(
        VSpacing(0.4),
        # RadioButton label
        Left(
          RadioButton(
            Id(:yes),
            Opt(:notify),
            _("&Yes, Test Connection to the Internet Via"),
            Internet.do_test
          )
        ),
        getDeviceContens(current),
        # RadioButton label
        Left(
          RadioButton(
            Id(:no),
            Opt(:notify),
            _("N&o, Skip This Test"),
            !Internet.do_test
          )
        ),
        VSpacing(0.4)
      )

      # the steps
      steps = VBox()
      if !already_up
        # label text - one step of during network test
        steps = Builtins.add(steps, Left(Label(_("- Connect to the Internet"))))
      end
      # label text - one step of during network test
      steps = Builtins.add(
        steps,
        Left(Label(_("- Download latest release notes")))
      )
      if Product.run_you
        # label text - one step of during network test
        steps = Builtins.add(
          steps,
          Left(Label(_("- Check for latest updates")))
        )
      end
      if !already_up
        # label text - one step of during network test
        steps = Builtins.add(steps, Left(Label(_("- Close connection"))))
      end

      # Steps dialog contents
      contents = HBox(
        #	`HSpacing(5),
        HStretch(),
        VBox(
          Left(Label(label)),
          VSpacing(1),
          # Heading text
          Left(Heading(_("The following steps will be performed:"))),
          VSpacing(1),
          steps,
          VSpacing(2),
          Left(
            HSquash(
              # Frame label
              Frame(
                _("Select:"),
                RadioButtonGroup(
                  Id(:rb),
                  HBox(HSpacing(2), buttons, HSpacing(2))
                )
              )
            )
          ),
          VSpacing(1)
        ),
        #	`HSpacing(5)
        HStretch()
      )

      Wizard.SetContents(caption, contents, help, true, true)
      Wizard.SetTitleIcon("yast-network")
      initDevice(items)

      ret = nil
      quit = false
      loop do
        ret = Convert.to_symbol(UI.UserInput)
        case ret
        when :net_expert
          current = handleDevice(items, current)
        when :abort, :cancel
          quit = true if Popup.ConfirmAbort(:incomplete)
        when :back, :next
          quit = true
        when :yes
          enableDevices(Ops.greater_than(Builtins.size(items), 1))
        when :no
          enableDevices(false)
        else
          Builtins.y2error("Unexpected return code:%1", ret)
        end
        break if quit
      end

      Internet.do_test = UI.QueryWidget(Id(:rb), :CurrentButton) == :yes
      SetDevice(current)
      Builtins.y2debug("Internet::do_test=%1", Internet.do_test)

      ret
    end

    # Connection test dialog
    # @return dialog result
    def AskYOUDialog
      # Radiobuttons
      buttons = VBox(
        VSpacing(1),
        # RadioButton label
        Left(RadioButton(Id(:yes), _("&Yes, Run Online Update Now"), true)),
        # RadioButton label
        Left(RadioButton(Id(:no), _("N&o, Skip Update"), false)),
        VSpacing(1)
      )

      # Dialog Content
      content = HBox(
        HSpacing(1),
        VBox(
          VSpacing(1),
          # Heading text
          Left(Heading(_("Online Updates Available"))),
          VSpacing(1),
          # Label text
          Label(_("Download and install them via the YaST Online Update?")),
          RadioButtonGroup(HBox(HSpacing(2), buttons, HSpacing(2))),
          HBox(PushButton(Opt(:default), Label.OKButton)),
          VSpacing(0.5)
        ),
        HSpacing(1)
      )

      UI.OpenDialog(content)
      UI.UserInput

      Internet.do_you = Convert.to_boolean(UI.QueryWidget(Id(:yes), :Value))
      Builtins.y2debug("Internet::do_you=%1", Internet.do_you)

      UI.CloseDialog

      nil
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
