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

require "y2network/widgets/path_widget"

module Y2Network
  module Widgets
    class ServerCAPath < PathWidget
      def initialize(builder)
        textdomain "network"
        @builder = builder
      end

      # FIXME: label and help text is wrong, here it is certificate of CA that is used to sign server certificate
      def label
        _("&Server Certificate")
      end

      def help
        "<p>To increase security, it is recommended to configure\n" \
          "a <b>Server Certificate</b>. It is used\n" \
          "to validate the server's authenticity.</p>\n"
      end

      def browse_label
        _("Choose a Certificate")
      end

      def init
        self.value = @builder.ca_cert
      end

      def store
        @builder.ca_cert = value
      end
    end
  end
end
