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
    class MTU < CWM::ComboBox
      def initialize(settings)
        textdomain "network"
        @settings = settings
      end

      def label
        _("Set &MTU")
      end

      def opt
        [:hstretch, :editable]
      end

      def default_items
        [
          # translators: MTU value description (size in bytes, desc)
          ["1500", _("1500 (Ethernet, DSL broadband)")],
          ["1492", _("1492 (PPPoE broadband)")],
          ["576", _("576 (dial-up)")]
        ]
      end

      def ipoib_items
        [
          # translators: MTU value description (size in bytes, desc)
          ["65520", _("65520 (IPoIB in connected mode)")],
          ["2044", _("2044 (IPoIB in datagram mode)")]
        ]
      end

      def items
        @settings.type.infiniband? ? ipoib_items : default_items
      end

      def init
        change_items(items)
        self.value = @settings.mtu
      end

      def store
        @settings.mtu = value
      end
    end
  end
end
