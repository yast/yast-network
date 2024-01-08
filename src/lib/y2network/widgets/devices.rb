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

require "y2network/interface"
require "cwm/common_widgets"

module Y2Network
  module Widgets
    class Devices < CWM::ComboBox
      # @param route route object to get and store gateway value
      def initialize(route, available_devices)
        super()
        textdomain "network"

        @devices = available_devices
        @route = route
      end

      def label
        _("De&vice")
      end

      def help
        _(
          "<p><b>Device</b> specifies the device through which the traffic" \
          " to the defined network will be routed.</p>"
        )
      end

      def items
        # TODO: maybe some translated names?
        @devices.map { |d| [d, d] }
      end

      def opt
        [:hstretch, :editable]
      end

      def init
        interface = @route.interface
        self.value = interface ? interface.name : ""
      end

      def store
        interface = value
        @route.interface = interface.empty? ? nil : Interface.new(interface)
      end
    end
  end
end
