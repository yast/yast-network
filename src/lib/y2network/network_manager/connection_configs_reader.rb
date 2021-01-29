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
require "cfa/nm_connection"
require "y2network/connection_configs_collection"
require "y2network/network_manager/connection_config_reader"

module Y2Network
  module NetworkManager
    # This class reads connection configurations from NetworkManager
    class ConnectionConfigsReader
      # Returns the connection configurations from NetworkManager
      #
      # @return [Y2Network::ConnectionConfigsCollection]
      def connections
        empty_collection = ConnectionConfigsCollection.new
        CFA::NmConnection.all.each_with_object(empty_collection) do |file, conns|
          connection = ConnectionConfigReader.new.read(file)
          conns << connection if connection
        end
      end
    end
  end
end
