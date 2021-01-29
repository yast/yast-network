# Copyright (c) [2021] SUSE LLC
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
require "y2network/config_reader"
require "y2network/backends"
require "y2network/network_manager/connection_configs_reader"

module Y2Network
  module NetworkManager
    # This class reads the current network configuration from NetworkManager
    class ConfigReader < Y2Network::ConfigReader
      SECTIONS = [
        :interfaces, :connections
      ].freeze

      def config
        Y2Network::Config.new(
          connections: connection_configs_reader.connections,
          backend:     Y2Network::Backends::NetworkManager.new,
          source:      :network_manager
        )
      end

    private

      def connection_configs_reader
        @connection_configs_reader ||= Y2Network::NetworkManager::ConnectionConfigsReader.new
      end
    end
  end
end
