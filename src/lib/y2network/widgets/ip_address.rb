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
Yast.import "Popup"

module Y2Network
  module Widgets
    # Input field that permits to modify an objet IP address
    class IPAddress < CWM::InputField
      # Constructor
      #
      # @param settings [Object] Object with an :ip_address accessor
      # @param focus [Boolean] whether the widget should get the focus when
      #   init; by default will not get it
      def initialize(settings, focus: false)
        textdomain "network"

        @settings = settings
        @focus = focus
      end

      def label
        _("&IP Address")
      end

      def help
        # TODO: write it
        ""
      end

      def opt
        [:hstretch]
      end

      def init
        self.value = @settings.ip_address
        focus if @focus
      end

      def store
        @settings.ip_address = value
      end

      def validate
        return true if Yast::IP.Check(value)

        Yast::Popup.Error(_("No valid IP address."))
        focus
        false
      end
    end
  end
end
