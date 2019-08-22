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
    class WirelessAuthMode < CWM::ComboBox
      def initialize(settings)
        textdomain "network"

        @settings = settings
      end

      def init
        self.value = @settings.auth_mode
      end

      def label
        _("&Authentication Mode")
      end

      def opt
        [:hstretch, :notify]
      end

      def items
        [
          ["no-encryption", _("No Encryption")],
          ["open", _("WEP - Open")],
          ["sharedkey", _("WEP - Shared Key")],
          ["wpa-psk", _("WPA-PSK (\"home\")")],
          ["wpa-eap", _("WPA-EAP (\"Enterprise\")")]
        ]
      end

      def help
        # TODO: improve help text, mention all options and security problems with WEP
        "<p>WPA-EAP uses a RADIUS server to authenticate users. There\n" \
        "are different methods in EAP to connect to the server and\n" \
        "perform the authentication, namely TLS, TTLS, and PEAP.</p>\n"
      end

      def store
        @settings.auth_mode = value
      end
    end
  end
end
