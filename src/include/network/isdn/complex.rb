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
# File:	include/network/isdn/complex.ycp
# Package:	Configuration of network
# Summary:	Summary and overview dialogs for ISDN configuration.
# Authors:	Michal Svec <msvec@suse.cz>
#
module Yast
  module NetworkIsdnComplexInclude
    def initialize_network_isdn_complex(include_target)
      Yast.import "UI"

      textdomain "network"

      Yast.import "CWM"
      Yast.import "CWMTab"
      Yast.import "ISDN"
      Yast.import "Label"
      Yast.import "Mode"
      Yast.import "Popup"
      Yast.import "Provider"
      Yast.import "Wizard"
      Yast.import "WizardHW"

      Yast.include include_target, "network/routines.rb"
      Yast.include include_target, "network/summary.rb"

      @selected_tab = "devices"
    end

    # Return a modification status
    # @return true if data was modified
    def Modified
      ISDN.Modified || Provider.Modified("isdn")
    end

    # Commit changes to internal structures
    # @return always `next
    def Commit
      ISDN.Commit
      :next
    end

    # Read settings dialog
    # @return `abort if aborted and `next otherwise
    def ReadDialog
      # isdns read dialog help 1/2
      helptext = _(
        "<P><B><BIG>Initializing ISDN Card Configuration\n</BIG></B><BR>Please wait...<BR></P>\n"
      )

      # isdns read dialog help 2/2
      helptext = Ops.add(
        helptext,
        _(
          "<P><B><BIG>Aborting the Initialization\n" +
            "</BIG></B><BR>You can safely abort the configuration utility by pressing\n" +
            "<B>Abort</B> now.</P>\n"
        )
      )

      Wizard.RestoreHelp(helptext)
      ISDN.AbortFunction = lambda { PollAbort() }
      ret = ISDN.Read
      ret ? :next : :abort
    end

    # Write settings dialog
    # @return `abort if aborted and `next otherwise
    def WriteDialog
      return :next if !Modified()

      # isdns write dialog help 1/2
      helptext = _(
        "<P><B><BIG>Saving ISDN Card Configuration\n</BIG></B><BR>Please wait...<BR></P>\n"
      )

      # isdns write dialog help 2/2
      helptext = Ops.add(
        helptext,
        _(
          "<P><B><BIG>Aborting Saving:</BIG></B><BR>\n" +
            "You can abort the save procedure by pressing <B>Abort</B>.\n" +
            "An additional dialog informs you whether it is safe to do so.</P>\n"
        )
      )

      Wizard.RestoreHelp(helptext)
      ISDN.AbortFunction = lambda { PollAbort() && ReallyAbort() }
      ret = ISDN.Write(true)
      ret ? :next : :abort
    end

    # Ask to handle provider or interface
    # in edit and delete functions
    #
    # @param [String] op  "edit" or "delete"
    # @return dialog result
    def Provider_or_IF(op)
      ret = nil
      # popup text to select between Interface or Provider for edit or delete 1/2
      txt = op == "edit" ?
        # popup text to select between Interface or Provider
        _("Select the item to edit.") :
        # popup text to select between Interface or Provider
        _("Select the item to delete.")
      UI.OpenDialog(
        Opt(:decorated),
        HBox(
          HSpacing(1),
          VBox(
            VSpacing(1),
            Label(txt),
            VSpacing(2),
            HBox(
              # PushButton label
              PushButton(Id(:interface), _("&Interface")),
              HSpacing(1),
              # PushButton label
              PushButton(Id(:provider), Opt(:default), _("&Provider"))
            ),
            VSpacing(1)
          ),
          HSpacing(1)
        )
      )
      while true
        ret = UI.UserInput
        break if ret == :interface || ret == :provider
      end
      UI.CloseDialog
      deep_copy(ret)
    end

    def InitDevices(widget_id)
      overview = Convert.convert(
        ISDN.OverviewDev,
        :from => "list",
        :to   => "list <map <string, any>>"
      )
      overview = Ops.add(overview, ISDN.UnconfiguredDev)

      Builtins.y2milestone("Init ISDN devices: %1", overview)
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
        ISDN.OverviewDev,
        :from => "list",
        :to   => "list <map <string, any>>"
      )
      overview = Ops.add(overview, ISDN.UnconfiguredDev)

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
        ISDN.Add
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
          ISDN.Add
          ISDN.SelectHW(i) # configured
        else
          ISDN.Edit(dev)
        end
        @selected_tab = "devices"
        return :edit
      # delete
      elsif ret == :delete
        dev = WizardHW.SelectedItem
        return nil if Builtins.substring(dev, 0, 1) == "-" # unconfigured

        ISDN.Delete(dev)
        ISDN.Commit
        InitDevices("devices")
        return nil
      end

      nil
    end

    def InitProviders(widget_id)
      overview = Convert.convert(
        Provider.Overview("isdn"),
        :from => "list",
        :to   => "list <map <string, any>>"
      )

      Builtins.y2milestone("Init ISDN devices: %1", overview)
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
        Provider.Overview("isdn"),
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
        Provider.Add("isdn")
        @selected_tab = "providers"
        return :Add
      # provider edit
      elsif ret == :edit || ret == :Table
        which = nil
        ret = Provider_or_IF("edit")
        if ret == :provider
          prov = WizardHW.SelectedItem
          if prov == nil
            Builtins.y2error("Empty device during Edit")
            return nil
          end
          ISDN.type = "net"
          Provider.Edit(prov)
          ISDN.operation = :editprov
          which = :Editprov
        else
          if ISDN.SelectInterface(true)
            ifstr = Builtins.sformat("net%1", ISDN.device)
            ISDN.EditIf(ifstr)
            which = :Editif
          else
            return nil
          end
        end
        @selected_tab = "providers"
        return which
      # provider delete
      elsif ret == :delete
        ret = Provider_or_IF("delete")
        if ret == :provider
          dev = WizardHW.SelectedItem
          ifc = ISDN.GetInterface4Provider(dev)
          if ifc == ""
            Provider.Delete(dev)
            Provider.Commit
          else
            txt = Builtins.sformat(
              # Popup::Message text
              _(
                "You tried to delete a provider that\n" +
                  "is the default provider for interface\n" +
                  "%1. First select another\n" +
                  "default provider for interface %2\n" +
                  "or delete the interface itself.\n"
              ),
              ifc,
              ifc
            )
            Popup.Message(txt)
          end
        else
          if ISDN.SelectInterface(true)
            ifstr = Builtins.sformat("net%1", ISDN.device)
            ISDN.Delete(ifstr)
            ISDN.Commit
          end
        end
        InitProviders("providers")
        return nil
      end

      nil
    end


    # Overview dialog
    # @return dialog result
    def OverviewDialog
      # ISDN overview dialog caption
      # dialog title
      caption = _("ISDN Configuration Overview")

      helptext = _(
        "<P><B><BIG>ISDN Card Overview</BIG></B><BR>\n" +
          "Here, get an overview of installed ISDN cards and connection setups.\n" +
          "Additionally you can edit their configurations.<BR></P>\n"
      ) # isdns overview dialog help 1/5

      # isdns overview dialog help 2/5
      helptext = Ops.add(
        helptext,
        _(
          "<P><B><BIG>Adding an ISDN Card:</BIG></B><BR>\nPress <B>Add</B> to configure an ISDN card manually.</P>\n"
        )
      )

      # isdns overview dialog help 3/5
      helptext = Ops.add(
        helptext,
        _(
          "<P><B><BIG>Test an ISDN Card Setup:</BIG></B><BR>\n" +
            "If you press <B>Test</B>, the system tries to load the driver for the\n" +
            "selected card.</P>\n"
        )
      )

      # isdns overview dialog help 4/5
      helptext = Ops.add(
        helptext,
        _(
          "<P><B><BIG>Adding an ISDN Connection:</BIG></B><BR>\nIf you press <B>Add</B>, you can configure an ISDN dial-up connection.</P>\n"
        )
      )

      # isdns overview dialog help 5/5
      helptext = Ops.add(
        helptext,
        _(
          "<P><B><BIG>Editing or Deleting:</BIG></B><BR>\n" +
            "Choose an ISDN card or connection to change or remove.\n" +
            "Then press the appropriate button: <B>Edit</B> or <B>Delete</B>.</P>\n"
        )
      )

      overview = ISDN.OverviewDev
      overviewp = Provider.Overview("isdn")
      #list overviewif = ISDN::OverviewIf();
      Builtins.y2debug("overview=%1", overview)
      Builtins.y2debug("overviewp=%1", overviewp)

      # use CWMTab for connections and providers
      widget_descr = {
        "devices"   => WizardHW.CreateWidget(
          [_("Device"), _("Type"), _("Hardware")],
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
                "header"       => _("ISDN Devices"),
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
          #	    "next_button": (Mode::normal ()? Label::FinishButton(): Label::NextButton()),
          # button labeling (fate#120373)
          "next_button"     => Label.OKButton(
          ),
          "abort_button"    => Label.CancelButton,
          # #54027
          "disable_buttons" => Mode.normal ? ["back_button"] : []
        }
      )
    end
  end
end
