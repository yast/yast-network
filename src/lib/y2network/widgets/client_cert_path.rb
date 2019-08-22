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
    class ClientCertPath < PathWidget
      def initialize(builder)
        textdomain "network"
        @builder = builder
      end

      # FIXME: label and help text is wrong, here it is certificate of CA that is used to sign server certificate
      def label
        _("&Client Certificate")
      end

      def help
        _(
          "<p>TLS uses a <b>Client Certificate</b> instead of a username and\n" \
            "password combination for authentication. It uses a public and private key pair\n" \
            "to encrypt negotiation communication, therefore you will additionally need\n" \
            "a <b>Client Key</b> file that contains your private key and\n" \
            "the appropriate <b>Client Key Password</b> for that file.</p>\n"
        )
      end

      def browse_label
        _("Choose a Certificate")
      end

      def init
        self.value = @builder.client_cert
      end

      def store
        @builder.client_cert = value
      end
    end
  end
end
