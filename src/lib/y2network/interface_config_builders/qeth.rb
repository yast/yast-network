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
    # Builder for S390 qeth interfaces. It also assumes the activation
    # responsibilities.
    class Qeth < InterfaceConfigBuilder
      extend Forwardable

      # Constructor
      #
      # @param config [Y2Network::ConnectionConfig::Base, nil] existing configuration of device or
      #   nil for newly created
      def initialize(config: nil)
        super(type: InterfaceType::QETH, config: config)
      end

      def_delegators :@connection_config,
        :read_channel, :read_channel=,
        :write_channel, :write_channel=,
        :data_channel, :data_channel=,
        :layer2, :layer2=,
        :port_number, :port_number=,
        :lladdress, :lladdress=,
        :ipa_takeover, :ipa_takeover=,
        :attributes, :attributes=,
        :device_id, :device_id=
    end
  end
end
