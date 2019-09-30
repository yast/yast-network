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

module Y2Network
  module Widgets
    class IPoIBMode < CWM::RadioButtons
      def initialize(config)
        textdomain "network"

        @config = config
      end

      def items
        # ipoib_modes contains known IPoIB modes, "default" is place holder for
        # "do not set anything explicitly -> driver will choose"
        # translators: a possible value for: IPoIB device mode
        [
          ["default", _("default")],
          ["connected", _("connected")],
          ["datagram", _("datagram")]
        ]
      end

      def label
        _("IPoIB Device Mode")
      end

      def opt
        [:hstretch]
      end

      def init
        self.value = @config.ipoib_mode
      end

      def store
        @config.ipoib_mode = value
      end
    end
  end
end
