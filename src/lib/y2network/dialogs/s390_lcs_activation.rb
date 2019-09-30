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

require "y2network/dialogs/s390_device_activation"

module Y2Network
  module Dialogs
    # Dialog for activating a LCS s390 device
    class S390LcsActivation < S390DeviceActivation
      def contents
        textdomain "network"

        HBox(
          HSpacing(6),
          # Frame label
          Frame(
            _("S/390 Device Settings"),
            HBox(
              HSpacing(2),
              VBox(
                VSpacing(1),
                # TextEntry label
                protocol_widget,
                VSpacing(1),
                HBox(
                  read_channel_widget,
                  HSpacing(1),
                  write_channel_widget
                )
              ),
              HSpacing(2)
            )
          ),
          HSpacing(6)
        )
      end

    private

      def protocol_widget
        Y2Network::Widgets::S390Protocol.new(builder)
      end

      def read_channel_widget
        Y2Network::Widgets::S390ReadChannel.new(builder)
      end

      def write_channel_widget
        Y2Network::Widgets::S390WriteChannel.new(builder)
      end

      def timeout_widget
        Y2network::Widgets::S390LanCmdTimeout.new(builder)
      end
    end
  end
end
