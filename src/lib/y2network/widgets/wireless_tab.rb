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
require "y2network/widgets/wireless"
require "y2network/widgets/wireless_auth"
require "y2network/dialogs/wireless_expert_settings"

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
          VSpacing(0.2),
          Y2Network::Widgets::Wireless.new(@builder),
          VSpacing(0.2),
          Y2Network::Widgets::WirelessAuth.new(@builder),
          VSpacing(0.2),
          Right(Y2Network::Widgets::WirelessExpertSettings.new(@builder)),
          VStretch()
        )
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
