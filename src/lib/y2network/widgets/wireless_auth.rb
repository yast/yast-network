# Copyright (c) [2019] SUSE LLC
#
# All Rights Reserved.
#
# This program is free software; you can redistribute it and/or modify it
# under the terms of version 2 of the GNU General Public License as published
# by the Free Software Foundation.
#
# This program is distributed in the hope that it will be useful, but WITHOUT
# ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or
# FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License for
# more details.
#
# You should have received a copy of the GNU General Public License along
# with this program; if not, contact SUSE LLC.
#
# To contact SUSE LLC about this file by physical or electronic mail, you may
# find current contact information at www.suse.com.

require "cwm/custom_widget"
require "cwm/replace_point"

require "y2network/dialogs/wireless_wep_keys"
require "y2network/widgets/wireless_auth_mode"
require "y2network/widgets/wireless_eap"
require "y2network/widgets/wireless_password"

module Y2Network
  module Widgets
    # Top level widget for wireless authentication. It changes content dynamically depending
    # on selected authentication method.
    class WirelessAuth < CWM::CustomWidget
      attr_reader :settings

      # @param settings [Y2network::InterfaceConfigBuilder]
      def initialize(settings)
        @settings = settings
        self.handle_all_events = true
        textdomain "network"
      end

      def init
        auth_mode_widget.init # force init of auth to ensure that refresh has correct value
        replace_widget.init
        refresh
      end

      def handle(event)
        return if event["ID"] != auth_mode_widget.widget_id

        refresh
        nil
      end

      def contents
        Frame(
          _("Authentication"),
          VBox(
            auth_mode_widget,
            VSpacing(0.2),
            replace_widget
          )
        )
      end

      # Sets the authentication mode
      #
      # It sets the auth mode to the given value and refreshes the widgets accordingly.
      #
      # @param mode [Symbol] Authentication mode
      def auth_mode=(mode)
        auth_mode_widget.value = mode.to_s
        refresh
      end

    private

      def refresh
        case auth_mode_widget.value
        when "none" then replace_widget.replace(empty_auth_widget)
        when "shared", "sharedkey", "open" then replace_widget.replace(wep_keys_widget)
        when "psk" then replace_widget.replace(encryption_widget)
        when "eap" then replace_widget.replace(eap_widget)
        else
          raise "invalid value #{auth_mode_widget.value.inspect}"
        end
      end

      def replace_widget
        @replace_widget ||= CWM::ReplacePoint.new(id:     "wireless_replace_point",
          widget: empty_auth_widget)
      end

      def empty_auth_widget
        @empty_auth_widget ||= CWM::Empty.new("wireless_empty")
      end

      def auth_mode_widget
        @auth_mode_widget ||= WirelessAuthMode.new(settings)
      end

      def encryption_widget
        @encryption_widget ||= WirelessPassword.new(settings)
      end

      def wep_keys_widget
        @wep_keys_widget ||= WirelessWepKeys.new(settings)
      end

      def eap_widget
        @eap_widget ||= WirelessEap.new(settings)
      end

      # Button for showing WEP Keys dialog
      class WirelessWepKeys < CWM::PushButton
        def initialize(settings)
          @settings = settings
          textdomain "network"
        end

        def label
          _("&WEP Keys")
        end

        def handle
          Y2Network::Dialogs::WirelessWepKeys.run(@settings)

          nil
        end
      end
    end
  end
end
