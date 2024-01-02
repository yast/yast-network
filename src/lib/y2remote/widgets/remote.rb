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
require "cwm"
require "y2remote/remote"

Yast.import "Popup"
Yast.import "CWMFirewallInterfaces"

module Y2Remote
  module Widgets
    class RemoteSettings < CWM::CustomWidget
      def initialize
        super
        textdomain "network"

        @allow_web ||= AllowWeb.new
      end

      def init
        remote.disabled? ? @allow_web.disable : @allow_web.enable
      end

      def opt
        [:notify]
      end

      def handle(event)
        case event["ID"]
        when :disallow
          @allow_web.disable
        when :allow_with_vncmanager, :allow_without_vncmanager
          @allow_web.enable
        end

        nil
      end

      def store
        remote.disable!

        return if disallow?

        allow_manager? ? remote.enable_manager! : remote.enable!

        remote.enable_web! if allow_web?

        nil
      end

      def contents
        RadioButtonGroup(
          VBox(
            # Small spacing (bsc#988904)
            VSpacing(0.3),
            # RadioButton label
            Left(
              RadioButton(
                Id(:allow_with_vncmanager),
                Opt(:notify),
                _("&Allow Remote Administration With Session Management"),
                remote.with_manager?
              )
            ),
            # RadioButton label
            Left(
              RadioButton(
                Id(:allow_without_vncmanager),
                Opt(:notify),
                _("&Allow Remote Administration Without Session Management"),
                remote.enabled? && !remote.with_manager?
              )
            ),
            # RadioButton label
            Left(
              RadioButton(
                Id(:disallow),
                Opt(:notify),
                _("&Do Not Allow Remote Administration"),
                remote.disabled?
              )
            ),
            VSpacing(1),
            Left(@allow_web)
          )
        )
      end

      def help
        Yast::Builtins.sformat(
          _(
            "<p><b><big>Remote Administration Settings</big></b></p>\n" \
            "<p>If this feature is enabled, you can\n" \
            "administer this machine remotely from another machine. Use a VNC\n" \
            "client, such as krdc (connect to <tt>&lt;hostname&gt;:%1</tt>), or\n" \
            "a Java-capable Web browser (connect to " \
            "<tt>https://&lt;hostname&gt;:%2/</tt>).</p>\n" \
            "<p>Without Session Management, only one user can be connected\n"\
            "at a time to a session, and that session is terminated when the VNC client\n" \
            "disconnects.</p>" \
            "<p>With Session Management, multiple users can interact with a single\n" \
            "session, and the session may persist even if noone is connected.</p>"
          ),
          5901,
          5801
        )
      end

    private

      # Convenience method to obtain a Y2Remote::Remote instance
      #
      # @return [Y2Remote::Remote] instance
      def remote
        @remote ||= Y2Remote::Remote.instance
      end

      # Return whether the disallow widget is checked
      #
      # @return [Boolean] true if checked
      def disallow?
        Yast::UI.QueryWidget(Id(:disallow), :Value)
      end

      def allow_without_manager?
        Yast::UI.QueryWidget(Id(:allow_without_vncmanager), :Value)
      end

      def allow_manager?
        Yast::UI.QueryWidget(Id(:allow_with_vncmanager), :Value)
      end

      # Return whether the vnc web access checkbox has been checked
      #
      # @return [Boolean] true if the web access checkbox is checked
      def allow_web?
        !disallow? && @allow_web.checked?
      end
    end

    # Checkbox widget for setting vnc web access as enabled when checked.
    class AllowWeb < CWM::CheckBox
      def initialize
        super
        textdomain "network"
      end

      def label
        _("Enable access using a &web browser")
      end

      def init
        self.value = Y2Remote::Remote.instance.web_enabled?
      end

      def opt
        [:notify]
      end
    end

    # Widget for opening VNC services in the firewall
    class RemoteFirewall < CWM::CustomWidget
      attr_accessor :cwm_interfaces

      # Constructor
      def initialize
        super
        textdomain "network"
        @cwm_interfaces = Yast::CWMFirewallInterfaces.CreateOpenFirewallWidget(
          "services"        => services,
          "display_details" => true
        )
      end

      def opt
        [:notify]
      end

      def init
        Yast::CWMFirewallInterfaces.OpenFirewallInit(cwm_interfaces, "")
      end

      def contents
        cwm_interfaces["custom_widget"]
      end

      def help
        cwm_interfaces["help"] || ""
      end

      def handle(event)
        Yast::CWMFirewallInterfaces.OpenFirewallHandle(cwm_interfaces, "", event)
      end

      # Applies the configuration of the vnc services according to the allowed
      # interfaces.
      def store
        Yast::CWMFirewallInterfaces.StoreAllowedInterfaces(services)
      end

    private

      # Convenience method to obtain the vnc firewalld services
      def services
        Y2Remote::Remote::FIREWALL_SERVICES
      end
    end
  end
end
