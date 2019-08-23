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

require "cwm/dialog"
require "y2network/widgets/s390_common"
require "y2network/widgets/s390_channels"

module Y2Network
  module Dialogs
    # Base class dialog for activating S390 devices
    class S390DeviceActivation < CWM::Dialog
      # @param type [Y2Network::InterfaceType] type of device
      # @return [S390DeviceActivation, nil]
      def self.for(type)
        case type.short_name
        when "qeth", "hsi"
          require "y2network/dialogs/s390_qeth_activation"
          Y2Network::Dialogs::S390QethActivation
        when "ctc"
          require "y2network/dialogs/s390_ctc_activation"
          Y2Network::Dialogs::S390CtcActivation
        when "lcs"
          require "y2network/dialogs/s390_lcs_activation"
          Y2Network::Dialogs::S390LcsActivation
        end
      end

      # Constructor
      #
      # @param settings [Y2Network::InterfaceConfigBuilder]
      def initialize(settings)
        textdomain "network"

        @settings = settings
        @settings.proposal
      end

      def title
        _("S/390 Network Card Configuration")
      end

      def contents
        Empty()
      end

      def abort_handler
        Yast::Popup.ReallyAbort(true)
      end
    end
  end
end
