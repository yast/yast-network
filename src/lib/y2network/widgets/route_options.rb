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

Yast.import "Netmask"
Yast.import "Label"

require "cwm/common_widgets"

module Y2Network
  module Widgets
    class RouteOptions < CWM::InputField
      # @param route route object to get and store options
      def initialize(route)
        textdomain "network"

        @route = route
      end

      def label
        Yast::Label.Options
      end

      def help
        _(
          "<p><b>Options</b> specifies additional options for route. It is directly passed " \
          "to <i>ip route add</i> with exception of <i>to</i>,<i>via</i> and <i>dev</i>."
        )
      end

      def opt
        [:hstretch]
      end

      def init
        self.value = @route.options
      end

      def store
        @route.options = value
      end
    end
  end
end
