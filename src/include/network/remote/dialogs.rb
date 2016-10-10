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
# File:	remote/dialogs.ycp
# Module:	Network configuration
# Summary:	Dialog for Remote Administration
# Authors:	Arvin Schnell <arvin@suse.de>
#
module Yast
  module NetworkRemoteDialogsInclude
    def initialize_network_remote_dialogs(_include_target)
      Yast.import "UI"

      textdomain "network"

      Yast.import "Label"
      Yast.import "Remote"
      Yast.import "Wizard"
      Yast.import "CWMFirewallInterfaces"
      Yast.import "Popup"
    end

    def DialogDone(event)
      action = event.to_sym

      return true if action == :next || action == :back
      return true if action == :abort || action == :cancel

      false
    end

    # Remote administration dialog
    # @return dialog result
    def RemoteMainDialog
      # Ramote Administration dialog caption
      caption = _("Remote Administration")

      allow_buttons = RadioButtonGroup(
        VBox(
          # Small spacing (bsc#988904)
          VSpacing(0.3),
          # RadioButton label
          Left(
            RadioButton(
              Id(:allow_with_vncmanager),
              _("&Allow Remote Administration With Session Management"),
              Remote.IsEnabled && Remote.EnabledVncManager
            )
          ),
          # RadioButton label
          Left(
            RadioButton(
              Id(:allow_without_vncmanager),
              _("&Allow Remote Administration Without Session Management"),
              Remote.IsEnabled && !Remote.EnabledVncManager
            )
          ),
          # RadioButton label
          Left(
            RadioButton(
              Id(:disallow),
              _("&Do Not Allow Remote Administration"),
              Remote.IsDisabled
            )
          )
        )
      )

      firewall_widget = CWMFirewallInterfaces.CreateOpenFirewallWidget(
        "services" => ["service:vnc-httpd", "service:vnc-server"], "display_details" => true
      )
      firewall_layout = Ops.get_term(firewall_widget, "custom_widget", VBox())
      firewall_help = Ops.get_string(firewall_widget, "help", "")

      # Remote Administration dialog help
      #    %1 and %2 are port numbers for vnc and vnchttp, eg. 5901, 5801
      help = Ops.add(
        Builtins.sformat(
          _(
            "<p><b><big>Remote Administration Settings</big></b></p>\n" \
              "<p>If this feature is enabled, you can\n" \
              "administer this machine remotely from another machine. Use a VNC\n" \
              "client, such as krdc (connect to <tt>&lt;hostname&gt;:%1</tt>), or\n" \
              "a Java-capable Web browser (connect to <tt>https://&lt;hostname&gt;:%2/</tt>).</p>\n" \
              "<p>Without Session Management, only one user can be connected\n"\
              "at a time to a session, and that session is terminated when the VNC client\n" \
              "disconnects.</p>" \
              "<p>With Session Management, multiple users can interact with a single\n" \
              "session, and the session may persist even if noone is connected.</p>"
          ),
          5901,
          5801
        ),
        firewall_help
      )

      # Remote Administration dialog contents
      contents = HBox(
        HStretch(),
        VBox(
          Frame(
            # Dialog frame title
            _("Remote Administration Settings"),
            allow_buttons
          ),
          VSpacing(1),
          firewall_layout
        ),
        HStretch()
      )

      Wizard.SetContentsButtons(
        caption,
        contents,
        help,
        Label.BackButton,
        Label.FinishButton
      )
      Wizard.SetNextButton(:next, Label.OKButton)
      Wizard.SetAbortButton(:abort, Label.CancelButton)
      Wizard.HideBackButton

      CWMFirewallInterfaces.OpenFirewallInit(firewall_widget, "")

      ret = nil
      event = nil
      loop do
        event = UI.WaitForEvent
        ret = Ops.get(event, "ID")

        CWMFirewallInterfaces.OpenFirewallHandle(firewall_widget, "", event)

        Wizard.ShowHelp(help) if ret == :help
        break if DialogDone(ret)
      end
      if ret == :next
        CWMFirewallInterfaces.OpenFirewallStore(firewall_widget, "", event)

        allow_with_vncmanager = UI.QueryWidget(Id(:allow_with_vncmanager), :Value)
        allow_without_vncmanager = UI.QueryWidget(Id(:allow_without_vncmanager), :Value)

        if allow_with_vncmanager
          Remote.EnableVncManager
        elsif allow_without_vncmanager
          Remote.Enable
        else
          Remote.Disable
        end
      end

      Convert.to_symbol(ret)
    end
  end
end
