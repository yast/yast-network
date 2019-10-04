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
require "y2network/connection_configs_collection"
require "y2network/connection_config"
require "y2network/interface_type"

module Y2Network
  module Autoinst
    # This class is responsible of importing the AutoYast S390 devices section
    class S390DevicesReader
      # @return [AutoinstProfile::S390DevicesSection]
      attr_reader :section

      # @param section [AutoinstProfile::S390DevicesSection]
      def initialize(section)
        @section = section
      end

      # @return [ConnectionConfigsCollection] the imported connections configs
      def config
        connections = ConnectionConfigsCollection.new([])

        @section.devices.each do |device_section|
          config = create_config(device_section)
          next unless config

          case config
          when ConnectionConfig::Qeth
            load_qeth(config, device_section)
          when ConnectionConfig::Lcs
            load_lcs(config, device_section)
          when ConnectionConfig::Ctc
            load_ctc(config, device_section)
          end
          connections << config
        end

        connections
      end

    private

      def create_config(device_section)
        type = InterfaceType.from_short_name(device_section.type)
        return unless type
        ConnectionConfig.const_get(type.class_name).new
      end

      def load_qeth(config, device_section)
        config.read_channel, config.write_channel, config.data_channel = device_section.chanids.split(" ")
        config.layer2 = device_section.layer2
      end

      def load_ctc(config, device_section)
        config.read_channel, config.write_channel = device_section.chanids.split(" ")
        config.protocol = device_section.protocol
      end

      def load_lcs(config, device_section)
        config.read_channel, config.write_channel = device_section.chanids.split(" ")
      end
    end
  end
end
