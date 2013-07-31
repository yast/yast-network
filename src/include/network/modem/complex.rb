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
# File:	include/network/modem/complex.ycp
# Package:	Network configuration
# Summary:	Summary, overview and IO dialogs for modems configuration.
# Authors:	Michal Svec <msvec@suse.cz>
#
module Yast
  module NetworkModemComplexInclude
    def initialize_network_modem_complex(include_target)
      Yast.import "UI"

      textdomain "network"

      Yast.import "CWM"
      Yast.import "CWMTab"
      Yast.import "Label"
      Yast.import "Mode"
      Yast.import "Modem"
      Yast.import "NetworkInterfaces"
      Yast.import "NetworkService"
      Yast.import "Popup"
      Yast.import "Provider"
      Yast.import "Routing"
      Yast.import "Wizard"
      Yast.import "WizardHW"

      Yast.include include_target, "network/routines.rb"
      Yast.include include_target, "network/summary.rb"


      @selected_tab = "devices"
    end

    # Return a modification status
    # @return true if data was modified
    def Modified
      Modem.Modified || Provider.Modified("modem")
    end

    # Commit changes to internal structures
    # @param [String] what what everything should be commited ("modem"|"provider"|"all")
    # @return always `next
    def Commit(what)
      Modem.Commit if what == "" || what == "all" || what == "modem"
      Provider.Commit if what == "" || what == "all" || what == "provider"
      :next
    end

    # Display finished popup
    # @return dialog result
    def FinishDialog
      FinishPopup(Modified(), "modem", "", "mail", ["dialup"])
    end

    # Read settings dialog
    # @return `abort if aborted and `next otherwise
    def ReadDialog
      # modems read dialog help 1/2
      helptext = _(
        "<P><B><BIG>Initializing Modem Configuration\n</BIG></B><BR>Please wait...<BR></P>"
      )

      # modems read dialog help 2/2
      helptext = Ops.add(
        helptext,
        _(
          "<P><B><BIG>Aborting the Initialization\n" +
            "</BIG></B><BR>You can safely abort the configuration utility by pressing\n" +
            "<B>Abort</B> now.</P>\n"
        )
      )

      Wizard.RestoreHelp(helptext)
      Modem.AbortFunction = lambda { PollAbort() }
      ret = Modem.Read

      # TODO move to Read, but then display only in interactive mode.
      # Or warn only when adding a provider.
      #     if (NetworkService::IsManaged ())
      #     {
      # 	// warning message when modem module starts up and NM is on
      # 	string warning = _("NetworkManager is enabled. Some features, such as
      # multiple providers for one modem, will not work.
      # You may want to use qinternet instead.");
      # 	Popup::LongWarning (warning);
      #     }
      ret ? :next : :abort
    end

    # Write settings dialog
    # @return `abort if aborted and `next otherwise
    def WriteDialog
      return :next if !Modified()

      # modems write dialog help 1/2
      helptext = _(
        "<P><B><BIG>Saving Modem Configuration</BIG></B><BR>\nPlease wait...<BR></P>"
      )

      # modems write dialog help 2/2
      helptext = Ops.add(
        helptext,
        _(
          "<P><B><BIG>Aborting Saving</BIG></B><BR>\n" +
            "You can abort the save process by pressing <B>Abort</B>. An additional\n" +
            "dialog may inform you whether it is safe to do so.</P>\n"
        )
      )

      Wizard.RestoreHelp(helptext)
      Modem.AbortFunction = lambda { PollAbort() && ReallyAbort() }
      ret = Modem.Write
      ret ? :next : :abort
    end

    def InitDevices(widget_id)
      overview = Convert.convert(
        Modem.Overview,
        :from => "list",
        :to   => "list <map <string, any>>"
      )
      overview = Ops.add(overview, Modem.Unconfigured)

      Builtins.y2milestone("Init Modem devices: %1", overview)
      WizardHW.SetContents(overview)

      if Ops.greater_than(Builtins.size(overview), 0)
        WizardHW.SetSelectedItem(Ops.get_string(overview, [0, "id"], ""))
      end

      WizardHW.SetRichDescription(
        Ops.get_string(overview, [0, "rich_descr"], "")
      )

      nil
    end

    def RichTextDevices(id)
      # TODO: optimize
      overview = Convert.convert(
        Modem.Overview,
        :from => "list",
        :to   => "list <map <string, any>>"
      )
      overview = Ops.add(overview, Modem.Unconfigured)

      entry = Builtins.find(overview) { |dev| Ops.get(dev, "id") == id }

      Ops.get_string(entry, "rich_descr", id)
    end

    def HandleDevices(widget_id, event)
      event = deep_copy(event)
      ret = Ops.get(event, "ID")

      Builtins.y2security("Event: %1", event)

      if Ops.get(event, "EventReason") == "SelectionChanged"
        WizardHW.SetRichDescription(RichTextDevices(WizardHW.SelectedItem))
        return nil
      end

      # add
      if ret == :add
        Modem.Add
        Provider.Add("modem")
        @selected_tab = "devices"
        return :add
      # edit
      elsif ret == :edit
        dev = WizardHW.SelectedItem
        if dev == nil
          Builtins.y2error("Empty device during Edit")
          return nil
        end
        if Builtins.substring(dev, 0, 1) == "-" # unconfigured
          i = Builtins.tointeger(Builtins.substring(dev, 1))
          Modem.Add
          Provider.Add("modem")
          Modem.SelectHW(i)

          if Modem.Requires != [] && Modem.Requires != nil
            return nil if PackagesInstall(Modem.Requires) != :next
          end # configured
        else
          Modem.Edit(dev)
          Provider.Edit(Provider.Name)
        end
        @selected_tab = "devices"
        return :edit
      # delete
      elsif ret == :delete
        dev = WizardHW.SelectedItem
        return nil if Builtins.substring(dev, 0, 1) == "-" # unconfigured

        Modem.Delete(dev)
        Modem.Commit
        InitDevices("devices")
        return nil
      end

      nil
    end

    def InitProviders(widget_id)
      overview = Convert.convert(
        Provider.Overview("modem"),
        :from => "list",
        :to   => "list <map <string, any>>"
      )

      Builtins.y2milestone("Init modem devices: %1", overview)
      WizardHW.SetContents(overview)

      if Ops.greater_than(Builtins.size(overview), 0)
        WizardHW.SetSelectedItem(Ops.get_string(overview, [0, "id"], ""))
      end

      WizardHW.SetRichDescription(
        Ops.get_string(overview, [0, "rich_descr"], "")
      )

      nil
    end

    def RichTextProviders(id)
      # TODO: optimize
      overview = Convert.convert(
        Provider.Overview("modem"),
        :from => "list",
        :to   => "list <map <string, any>>"
      )

      entry = Builtins.find(overview) { |dev| Ops.get(dev, "id") == id }

      Ops.get_string(entry, "rich_descr", id)
    end

    def HandleProviders(widget_id, event)
      event = deep_copy(event)
      ret = Ops.get(event, "ID")

      if Ops.get(event, "EventReason") == "SelectionChanged"
        WizardHW.SetRichDescription(RichTextProviders(WizardHW.SelectedItem))
        return nil
      end

      # provider add
      if ret == :add
        Provider.Add("modem")
        @selected_tab = "providers"
        return :Add
      # provider edit
      elsif ret == :edit || ret == :Table
        dev = WizardHW.SelectedItem
        if dev == nil
          Builtins.y2error("Empty device during Edit")
          return nil
        end
        Provider.Edit(dev)
        @selected_tab = "providers"
        return :Edit
      # provider delete
      elsif ret == :delete
        dev = WizardHW.SelectedItem

        # Check if the provider is not used (#17497)
        if NetworkInterfaces.LocateProvider(dev)
          Builtins.y2debug("Provider used: %1", dev)

          # Popup text
          Popup.Error(Builtins.sformat(_("The provider %1 is in use."), dev))
          return nil

          # Popup text
          pop = Builtins.sformat(
            _("The provider %1 is in use. Really delete it?"),
            dev
          )
          return nil if !Popup.YesNo(pop)
        end

        Provider.Delete(dev)
        Provider.Commit
        InitProviders("providers")
        return nil
      end

      nil
    end


    # Overview dialog
    # @return dialog result
    def OverviewDialog
      # Modems overview dialog caption
      caption = _("Modem Configuration Overview")

      # modems overview dialog help 1/3
      helptext = _(
        "<P><B><BIG>Modem Overview</BIG></B><BR>\n" +
          "Here, get an overview of installed modems. Additionally,\n" +
          "edit their configuration.<BR></P>"
      )

      # modems overview dialog help 2/3
      helptext = Ops.add(
        helptext,
        _(
          "<P><B><BIG>Adding a Modem:</BIG></B><BR>\nIf you press <B>Add</B>, you can manually configure a modem.</P>\n"
        )
      )

      # modems overview dialog help 3/3
      helptext = Ops.add(
        helptext,
        _(
          "<P><B><BIG>Editing or Deleting:</BIG></B><BR>\n" +
            "Choose a modem for which to change or remove the configuration.\n" +
            "Then press the appropriate button: <B>Edit</B> or <B>Delete</B>.</P>"
        )
      )

      #     list overview = Modem::Overview();
      #     list overviewp = Provider::Overview("modem");
      #     y2debug("overview=%1",overview);
      #     y2debug("overviewp=%1",overviewp);

      # use CWMTab for connections and providers
      widget_descr = {
        "devices"   => WizardHW.CreateWidget(
          [_("Device"), _("Type"), _("Provider")],
          []
        ),
        "providers" => WizardHW.CreateWidget(
          [_("Name"), _("Provider"), _("Phone")],
          []
        )
      }

      Ops.set(
        widget_descr,
        ["devices", "init"],
        fun_ref(method(:InitDevices), "void (string)")
      )
      Ops.set(
        widget_descr,
        ["devices", "handle"],
        fun_ref(method(:HandleDevices), "symbol (string, map)")
      )
      Ops.set(widget_descr, ["devices", "help"], " ")
      Ops.set(
        widget_descr,
        ["providers", "init"],
        fun_ref(method(:InitProviders), "void (string)")
      )
      Ops.set(
        widget_descr,
        ["providers", "handle"],
        fun_ref(method(:HandleProviders), "symbol (string, map)")
      )
      Ops.set(widget_descr, ["providers", "help"], " ")

      Ops.set(
        widget_descr,
        "tab",
        CWMTab.CreateWidget(
          {
            "tab_order"    => ["devices", "providers"],
            "tabs"         => {
              "devices"   => {
                # tab header
                "header"       => _("Modem Devices"),
                "contents"     => VBox(
                  VSpacing(1),
                  HBox(HSpacing(1), "devices", HSpacing(1)),
                  VSpacing(1)
                ),
                "widget_names" => ["devices"]
              },
              "providers" => {
                # tab header
                "header"       => _("Providers"),
                "contents"     => VBox(
                  VSpacing(1),
                  HBox(HSpacing(1), "providers", HSpacing(1)),
                  VSpacing(1)
                ),
                "widget_names" => ["providers"]
              }
            },
            "widget_descr" => widget_descr,
            "initial_tab"  => @selected_tab,
            "tab_help"     => helptext
          }
        )
      )

      # shut up CWM
      Ops.set(widget_descr, ["tab", "help"], " ")

      # FIXME: reallyabort

      CWM.ShowAndRun(
        {
          "widget_descr"    => widget_descr,
          "contents"        => VBox("tab"),
          "caption"         => caption,
          "back_button"     => nil,
          # #182853
          "next_button"     => Label.OKButton,
          "abort_button"    => Label.CancelButton,
          # #54027
          "disable_buttons" => Mode.normal ? ["back_button"] : []
        }
      )
    end
  end
end
