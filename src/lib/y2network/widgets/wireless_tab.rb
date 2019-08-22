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
        _("&Wireless Specific")
      end

      def contents
        VBox(
          VSpacing(0.5),
          Y2Network::Widgets::Wireless.new(@builder),
          VSpacing(0.5),
          Y2Network::Widgets::WirelessAuth.new(@builder),
          VSpacing(0.5),
          # TODO: wireless auth widget
          VStretch()
        )
      end
    end
  end
end
