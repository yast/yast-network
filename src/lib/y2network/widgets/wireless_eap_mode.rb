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
    # Widget to select EAP mode.
    class WirelessEapMode < CWM::ComboBox
      # @param settings [Y2network::InterfaceConfigBuilder]
      def initialize(settings)
        super()
        textdomain "network"
        @settings = settings
      end

      def init
        self.value = @settings.eap_mode
      end

      def store
        @settings.eap_mode = value
      end

      def label
        _("EAP &Mode")
      end

      # generate event when changed so higher level widget can change content
      # @see Y2Network::Widgets::WirelessEap
      def opt
        [:notify, :hstretch]
      end

      def items
        [
          ["PEAP", _("PEAP")],
          ["TLS", _("TLS")],
          ["TTLS", _("TTLS")]
        ]
      end

      def help
        _(
          "<p>WPA-EAP uses a RADIUS server to authenticate users. There\n" \
          "are different methods in EAP to connect to the server and\n" \
          "perform the authentication, namely TLS, TTLS, and PEAP.</p>\n"
        )
      end
    end
  end
end
