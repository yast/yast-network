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
    # Dialog for activating a QETH device
    class S390QethActivation < S390DeviceActivation
      def contents
        textdomain "network"

        HBox(
          HSpacing(6),
          Frame(
            _("S/390 Device Settings"),
            HBox(
              HSpacing(2),
              VBox(
                VSpacing(1),
                HBox(
                  s390_port_number,
                  HSpacing(1),
                  s390_attributes
                ),
                VSpacing(1),
                Left(s390_ip_takeover),
                VSpacing(1),
                Left(s390_layer2),
                VSpacing(1),
                s390_channels
              ),
              HSpacing(2)
            )
          ),
          HSpacing(6)
        )
      end

    private

      def s390_port_number
        Y2Network::Widgets::S390PortNumber.new(@settings)
      end

      def s390_attributes
        Y2Network::Widgets::S390Attributes.new(@settings)
      end

      def s390_ip_takeover
        Y2Network::Widgets::S390IPAddressTakeover.new(@settings)
      end

      def s390_channels
        Y2Network::Widgets::S390Channels.new(@settings)
      end

      def s390_layer2
        Y2Network::Widgets::S390Layer2.new(@settings)
      end
    end
  end
end
