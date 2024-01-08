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
require "y2network/widgets/blink_button"
require "y2network/widgets/driver"
require "y2network/widgets/ethtools_options"

module Y2Network
  module Widgets
    class HardwareTab < CWM::Tab
      def initialize(settings)
        super()
        textdomain "network"

        @settings = settings
      end

      def label
        _("&Hardware")
      end

      def contents
        VBox(
          # FIXME: ensure that only eth, maybe also ib?
          eth? ? BlinkButton.new(@settings) : Empty(),
          Driver.new(@settings),
          # FIXME: probably makes sense only for eth
          EthtoolsOptions.new(@settings),
          VStretch()
        )
      end

      def eth?
        @settings.type.ethernet?
      end
    end
  end
end
