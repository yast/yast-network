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
    class BondOptions < CWM::ComboBox
      def initialize(settings)
        super()
        textdomain "network"
        @settings = settings
      end

      PRESET_ITEMS = [
        ["mode=balance-rr miimon=100", "mode=balance-rr miimon=100"],
        ["mode=active-backup miimon=100", "mode=active-backup miimon=100"],
        ["mode=balance-xor miimon=100", "mode=balance-xor miimon=100"],
        ["mode=broadcast miimon=100", "mode=broadcast miimon=100"],
        ["mode=802.3ad miimon=100", "mode=802.3ad miimon=100"],
        ["mode=balance-tlb miimon=100", "mode=balance-tlb miimon=100"],
        ["mode=balance-alb miimon=100", "mode=balance-alb miimon=100"]
      ].freeze

      def items
        PRESET_ITEMS
      end

      def help
        _(
          "<p>Select the bond driver options and edit them if necessary. </p>"
        )
      end

      def label
        _("&Bond Driver Options")
      end

      def opt
        [:hstretch, :editable]
      end

      def init
        self.value = @settings.bond_options
      end

      def store
        @settings.bond_options = value
      end
    end
  end
end
