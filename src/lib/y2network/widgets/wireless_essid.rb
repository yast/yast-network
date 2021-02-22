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

require "cwm/common_widgets"
require "cwm/custom_widget"
require "y2network/dialogs/wireless_networks"

Yast.import "String"
Yast.import "Package"
Yast.import "Stage"

module Y2Network
  module Widgets
    # Widget to setup wifi network essid
    class WirelessEssid < CWM::CustomWidget
      # @param settings [Y2network::InterfaceConfigBuilder]
      def initialize(settings)
        @settings = settings
        textdomain "network"
      end

      def contents
        HBox(
          essid,
          VBox(
            VSpacing(1),
            scan
          )
        )
      end

    private

      def essid
        @essid ||= WirelessEssidName.new(@settings)
      end

      def scan
        @scan ||= WirelessScan.new(@settings, update: essid)
      end
    end

    # Widget for network name combobox
    class WirelessEssidName < CWM::InputField
      # @param settings [Y2network::InterfaceConfigBuilder]
      def initialize(settings)
        @settings = settings
        textdomain "network"
      end

      def label
        _("Ne&twork Name (ESSID)")
      end

      def init
        Yast::UI.ChangeWidget(Id(widget_id), :ValidChars, valid_chars)
        self.value = @settings.essid.to_s
      end

      def store
        @settings.essid = value
      end

    private

      def valid_chars
        Yast::String.CPrint
      end
    end

    # Button for scan network sites
    class WirelessScan < CWM::PushButton
      # @param settings [Y2network::InterfaceConfigBuilder]
      # @param update [WirelessEssidName]
      def initialize(settings, update:)
        textdomain "network"

        @settings = settings
        @update_widget = update
      end

      def label
        _("Scan Network")
      end

      def init
        disable unless present?
      end

      def handle
        return unless scan_supported?

        selected = network_selector.run
        @update_widget&.value = selected.essid if selected

        nil
      end

    private

      IWLIST_PKG = "wireless-tools".freeze

      def present?
        !!@settings.interface&.hardware&.present?
      end

      def scan_supported?
        return true if install_needed_packages

        Yast::Popup.Error(
          _("The package %s was not installed. It is needed in order to " \
            "be able to scan the network") % IWLIST_PKG
        )
        false
      end

      # Require wireless-tools installation in order to be able to scan the
      # wlan network (bsc#1112952, bsc#1168479)
      #
      # TODO: drop it when supported by wicked directly
      def install_needed_packages
        Yast::Stage.initial ||
          Yast::Package.Installed(IWLIST_PKG) ||
          Yast::Package.Install(IWLIST_PKG)
      end

      def network_selector
        @network_selector ||= Y2Network::Dialogs::WirelessNetworks.new(@settings.interface)
      end

      def interface
        @settings.name
      end
    end
  end
end
