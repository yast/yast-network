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
require "y2network/widgets/hostname"

module Y2Network
  module Dialogs
    # A popup dialog which permits to modify the hostname mapped to the given
    # connection primary IP address
    class UpdateHostnameHosts < CWM::Popup
      def initialize(connection)
        textdomain "network"

        @connection = connection
      end

      def title
        format(_("Edit '%s' hostname"), @connection.name)
      end

      def contents
        VBox(
          Left(Label(_("IP Address"))),
          Left(Label(ip_address)),
          VSpacing(0.5),
          hostname_widget,
          VSpacing(0.5)
        )
      end

      def buttons
        [ok_button, cancel_button]
      end

      def ok_button_label
        Yast::Label.ModifyButton
      end

      def min_height
        8
      end

      def ip_address
        @connection&.ip&.address&.address&.to_s
      end

    private

      def hostname_widget
        @hostname_widget ||= Widgets::Hostname.new(@connection)
      end
    end
  end
end
