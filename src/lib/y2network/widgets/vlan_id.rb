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

module Y2Network
  module Widgets
    class VlanID < CWM::IntField
      def initialize(config)
        textdomain "network"

        @config = config
      end

      def label
        _("VLAN ID")
      end

      def help
        # TODO: previously not exist, so write it
        ""
      end

      def init
        self.value = @config.vlan_id
      end

      def store
        @config.vlan_id = value
      end

      def minimum
        0
      end

      def maximum
        9999
      end
    end
  end
end
