# Copyright (c) [2021] SUSE LLC
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
require "cwm/common_widgets"
require "y2network/dialogs/wireless_networks"

Yast.import "Stage"
Yast.import "Package"

module Y2Network
  module Widgets
    # Button for scan network sites
    class WirelessScanButton < CWM::PushButton
      # @param settings [Y2network::InterfaceConfigBuilder]
      # @param select_callback [Proc] Proc to be called when a network is selected
      def initialize(settings, &select_callback)
        super()
        textdomain "network"

        @settings = settings
        @select_callback = select_callback
      end

      def label
        _("Choose Network")
      end

      def init
        disable unless present?
      end

      def handle
        return unless scan_supported?

        selected = network_selector.run
        @select_callback.call(selected) if selected

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
        @network_selector ||= Y2Network::Dialogs::WirelessNetworks.new(@settings)
      end
    end
  end
end
