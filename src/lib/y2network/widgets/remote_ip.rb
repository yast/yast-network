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

require "yast"
require "cwm/common_widgets"

Yast.import "IP"

module Y2Network
  module Widgets
    class RemoteIP < CWM::InputField
      def initialize(settings)
        super()
        textdomain "network"

        @settings = settings
      end

      def label
        _("R&emote IP Address")
      end

      def help
        _(
          "<p>Enter the <b>IP Address</b> (for example: <tt>192.168.100.99</tt>) " \
          "for your computer, and the \n" \
          " <b>Remote IP Address</b> (for example: <tt>192.168.100.254</tt>)\n" \
          "for your peer.</p>\n"
        )
      end

      def init
        self.value = @settings.remote_ip
      end

      def store
        @settings.remote_ip = value
      end

      def validate
        return true if Yast::IP.Check(value)

        Yast::Popup.Error(_("The remote IP address is invalid.") + "\n" + Yast::IP.Valid4)
      end
    end
  end
end
