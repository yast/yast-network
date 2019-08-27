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
require "cwm/common_widgets"

Yast.import "NetworkInterfaces"

module Y2Network
  module Widgets
    class InterfaceType < CWM::RadioButtons
      attr_reader :result
      def initialize(default: nil)
        textdomain "network"
        # eth as default
        @default = default || "eth"
      end

      def label
        _("&Device Type")
      end

      def help
        # FIXME: help is not helpful
        _(
          "<p><b>Device Type</b>. Various device types are available, select \n" \
            "one according your needs.</p>"
        )
      end

      def init
        self.value = @default
      end

      def items
        Yast::NetworkInterfaces.GetDeviceTypes.map do |type|
          [type, Yast::NetworkInterfaces.GetDevTypeDescription(type, _long_desc = false)]
        end
      end

      def store
        @result = value
      end
    end
  end
end
