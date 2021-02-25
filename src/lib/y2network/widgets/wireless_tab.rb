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

require "yast"
require "cwm/tabs"

# used widgets
require "y2network/widgets/wireless_essid"
require "y2network/widgets/wireless_auth"
require "y2network/dialogs/wireless_expert_settings"
require "y2network/widgets/wireless_scan_button"

module Y2Network
  module Widgets
    # Tab for wireless specific stuff. Useful only for wireless cards
    class WirelessTab < CWM::Tab
      # @param builder [Y2network::InterfaceConfigBuilder]
      def initialize(builder)
        textdomain "network"

        @builder = builder
      end

      def label
        _("&Wireless")
      end

      def contents
        VBox(
          VSpacing(1),
          HBox(essid_widget, VBox(VSpacing(1), scan_button)),
          VSpacing(1),
          auth_widget,
          VSpacing(1),
          Right(Y2Network::Widgets::WirelessExpertSettings.new(@builder)),
          VStretch()
        )
      end

      # Selects the network
      #
      # It sets the ESSID and the authentication mode according to the given network.
      #
      # @param network [Y2Network::WirelessNetwork] Selected network
      def select_network(network)
        @builder.essid = network.essid
        @builder.auth_mode.to_sym
        essid_widget.value = network.essid
        auth_widget.auth_mode = network.auth_mode.short_name
      end

    private

      # Returns the button to scan for wireless networks
      #
      # @return [WirelessScan]
      def scan_button
        @scan_button ||= WirelessScanButton.new(@builder) { |n| select_network(n) }
      end

      # Returns the widget to set the wireless ESSID
      def essid_widget
        @essid_widget ||= Y2Network::Widgets::WirelessEssid.new(@builder)
      end

      def auth_widget
        @auth_widget ||= Y2Network::Widgets::WirelessAuth.new(@builder)
      end
    end

    class WirelessExpertSettings < CWM::PushButton
      def initialize(settings)
        @settings = settings

        textdomain "network"
      end

      def label
        _("E&xpert Settings")
      end

      def handle
        Y2Network::Dialogs::WirelessExpertSettings.new(@settings).run

        nil
      end
    end
  end
end
