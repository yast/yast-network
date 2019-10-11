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

Yast.import "IP"
Yast.import "Popup"
Yast.import "UI"

require "ipaddr"

require "cwm/common_widgets"

module Y2Network
  module Widgets
    class Gateway < CWM::InputField
      # @param route route object to get and store gateway value
      def initialize(route)
        textdomain "network"

        @route = route
      end

      def label
        _("&Gateway")
      end

      def help
        _(
          "<p><b>Gateway</b> defines the IP address of a host which routes the packets " \
            "to a remote host or network. It can be blank for rejection or device routes. "
        )
      end

      def opt
        [:hstretch]
      end

      def init
        Yast::UI.ChangeWidget(Id(widget_id), :ValidChars, Yast::IP.ValidChars + "-")

        self.value = @route.gateway.nil? ? "-" : @route.gateway.to_s
      end

      def validate
        return true if value == "-"

        return true if Yast::IP.Check(value)

        Yast::Popup.Error(_("Gateway IP address is invalid."))
        focus
        false
      end

      def store
        gw = value
        @route.gateway = (gw == "-") ? nil : IPAddr.new(gw)
      end
    end
  end
end
