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

require "y2network/dialogs/popup"
require "y2network/widgets/wireless_networks"

module Y2Network
  module Dialogs
    class WirelessNetworks < Popup
      def initialize(networks)
        textdomain "network"

        @networks = networks
      end

      def title
        _("Wireless Available Networks")
      end

      def contents
        networks_table
      end

    protected

      def min_width
        60
      end

    private

      def networks_table
        @networks_table ||= Y2Network::Widgets::WirelessNetworks.new(@networks)
      end
    end
  end
end
