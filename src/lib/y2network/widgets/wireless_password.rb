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
    # Widget for WPA "home" password. It is not used for EAP password.
    class WirelessPassword < CWM::Password
      # @param builder [Y2network::InterfaceConfigBuilder]
      def initialize(builder)
        textdomain "network"
        @builder = builder
      end

      def label
        _("Password")
      end

      def init
        self.value = @builder.wpa_psk
      end

      def store
        @builder.wpa_psk = value
      end

      # TODO: write help text

      # TODO: write validation. From man page: You can enter it in hex digits (needs to be exactly
      # 64 digits long) or as passphrase getting hashed (8 to 63 ASCII characters long).
    end
  end
end
