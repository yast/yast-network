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
    # Widget that represent EAP Client Key password
    class ClientKeyPassword < CWM::Password
      def initialize(builder)
        super()
        @builder = builder
        textdomain "network"
      end

      def opt
        [:hstretch]
      end

      def label
        _("Client Key Password")
      end

      def init
        self.value = @builder.client_key_password
      end

      def store
        @builder.client_key_password = value
      end

      def help
        "" # TODO: write it
      end
    end

    class ClientKeyPath < PathWidget
      def initialize(builder)
        super()
        textdomain "network"
        @builder = builder
      end

      def label
        _("Client &Key")
      end

      def help
        "" # TODO: was missing, write something
      end

      def browse_label
        _("Choose a File with Private Key")
      end

      def init
        self.value = @builder.client_key
      end

      def store
        @builder.client_key = value
      end
    end
  end
end
