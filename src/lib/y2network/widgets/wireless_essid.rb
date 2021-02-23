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

      # @see CWM::CustomWidget
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

      # Returns the ESSID input field
      #
      # Its value can be set manually or through the WirelessNetworks dialog.
      #
      # @return [WirelessEssidName]
      def essid
        @essid ||= WirelessEssidName.new(@settings)
      end
    end

    # Widget for network name input field
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
  end
end
