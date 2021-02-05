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
require "y2network/interface_config_builder"

module Y2Network
  module InterfaceConfigBuilders
    class Ctc < InterfaceConfigBuilder
      extend Forwardable

      Yast.import "NetworkConfig"

      def initialize(config: nil)
        super(type: InterfaceType::CTC, config: config)
      end

      def save
        # TODO: no one knows whether this ctc specific thing is still needed
        wfi = Yast::NetworkConfig.Config["WAIT_FOR_INTERFACES"].to_i

        Yast::Network.Config["WAIT_FOR_INTERFACES"] = [wfi, WAIT_FOR_INTERFACES].max

        super
      end

      WAIT_FOR_INTERFACES = 40
      private_constant :WAIT_FOR_INTERFACES

      def_delegators :@connection_config,
        :read_channel, :read_channel=,
        :write_channel, :write_channel=,
        :protocol, :protocol=,
        :device_id, :device_id=

    end
  end
end
