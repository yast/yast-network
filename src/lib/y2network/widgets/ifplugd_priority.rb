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
    class IfplugdPriority < CWM::IntField
      def initialize(config)
        textdomain "network"

        @config = config
      end

      def label
        _(
          "Ifplugd Priority"
        )
      end

      def help
        # TRANSLATORS: help text for Ifplugd priority widget
        _(
          "<p><b><big>IFPLUGD PRIORITY</big></b></p> \n" \
          "<p> All interfaces configured with <b>On Cable Connection</b> " \
          "and with IFPLUGD_PRIORITY != 0 will be\n" \
          " used mutually exclusive. If more then one of these interfaces " \
          "is <b>On Cable Connection</b>\n" \
          " then we need a way to decide which interface to take up. Therefore we have to\n" \
          " set the priority of each interface.  </p>\n"
        )
      end

      def minimum
        0
      end

      def maximum
        100
      end

      def init
        self.value = @config.ifplugd_priority
      end

      def store
        @config.ifplugd_priority = value.to_i if enabled?
      end
    end
  end
end
