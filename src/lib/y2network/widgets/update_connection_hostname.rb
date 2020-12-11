# Copyright (c) [2020] SUSE LLC
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

require "cwm"

module Y2Network
  module Widgets
    class UpdateConnectionHostname < CWM::CustomWidget
      def initialize(new_hostname, connection)
        textdomain "network"

        @hostname = new_hostname
        @connection = connection
      end

      def init
        ip_address_widget.disable
      end

      def contents
        VBox(
          ip_address_widget,
          VSpacing(0.5),
          hostname_widget,
          VSpacing(0.5)
        )
      end

    private

      def ip_address_widget
        @ip_address_widget ||= ConnectionIP.new(@connection)
      end

      def hostname_widget
        @hostname_widget ||= ConnectionHostname.new(@connection)
      end
    end

    class ConnectionIP < CWM::InputField
      def initialize(connection)
        @connection = connection
      end

      def init
        self.value = @connection&.ip&.address&.address&.to_s
      end

      def label
        _("&IP Address")
      end
    end

    class ConnectionHostname < CWM::InputField
      def initialize(connection)
        @connection = connection
      end

      def init
        self.value = @connection.hostname
      end

      def label
        _("&Hostname")
      end

      def store
        @connection.hostname = value
      end
    end
  end
end
