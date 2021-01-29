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
require "y2network/network_manager/connection_config_readers/base"

module Y2Network
  module NetworkManager
    module ConnectionConfigReaders
      class Wireless < Base
        # FIXME: (somehow) duplicated in the writer
        DEFAULT_MODE = "managed".freeze
        MODE = { "adhoc" => "ad-hoc", "ap" => "master", "infrastructure" => "managed" }.freeze

        # @see Y2Network::NetworkManager::ConnectionConfigReaders::Base#update_connection_config
        def update_connection_config(conn)
          conn.mtu = file.wifi["mtu"].to_i if file.wifi["mtu"]
          conn.mode = MODE[file.wifi["mode"]] || DEFAULT_MODE
          conn.essid = file.wifi["ssid"]
        end
      end
    end
  end
end
