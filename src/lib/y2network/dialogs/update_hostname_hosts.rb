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

require "cwm/popup"
require "y2network/dialogs/popup"
require "y2network/widgets/update_connection_hostname"

module Y2Network
  module Dialogs
    class UpdateHostnameHosts < Popup
      def initialize(hostname, connection)
        textdomain "network"

        @hostname = hostname
        @connection = connection
      end

      def title
        format(_("Edit '%s' static IP address hostname"), @connection.name)
      end

      def contents
        VBox(
          connection_hostname_widget
        )
      end

      def buttons
        [ok_button, cancel_button]
      end

      def ok_button_label
        _("Modify")
      end

      def min_height
        8
      end

    private

      def connection_hostname_widget
        @connection_hostname_widget ||=
          Widgets::UpdateConnectionHostname.new(@hostname, @connection)
      end
    end
  end
end
