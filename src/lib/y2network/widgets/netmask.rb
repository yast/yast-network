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
Yast.import "Netmask"
Yast.import "Popup"

module Y2Network
  module Widgets
    class Netmask < CWM::InputField
      def initialize(settings)
        super()
        textdomain "network"

        @settings = settings
      end

      def label
        _("&Subnet Mask")
      end

      def help
        # TODO: write it
        ""
      end

      def opt
        [:hstretch]
      end

      def init
        self.value = @settings.subnet_prefix
      end

      def store
        @settings.subnet_prefix = value
      end

      def validate
        return true if valid_netmask

        Yast::Popup.Error(_("No valid netmask or prefix length."))
        focus
        false
      end

      def valid_netmask
        mask = value
        mask = mask[1..-1] if mask.start_with?("/")

        Yast::Netmask.Check4(mask) || Yast::Netmask.CheckPrefix4(mask) || Yast::Netmask.Check6(mask)
      end
    end
  end
end
