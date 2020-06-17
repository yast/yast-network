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
    class IP4Forwarding < CWM::CheckBox
      def initialize(config)
        textdomain "network"

        @config = config
      end

      def init
        self.value = @config.routing.forward_ipv4
        disable if @config.backend?(:network_manager)
      end

      def store
        @config.routing.forward_ipv4 = value
      end

      def label
        _("Enable &IPv4 Forwarding")
      end

      def help
        _(
          "<p>Enable <b>IPv4 Forwarding</b> (forwarding packets from external networks\n" \
            "to the internal one) if this system is a router.\n" \
            "<b>Important:</b> if the firewall is enabled, allowing forwarding " \
            "alone is not enough. \n" \
            "You should enable masquerading and/or set at least one redirect rule in the\n" \
            "firewall configuration. Use the YaST firewall module.</p>\n"
        )
      end
    end
  end
end
