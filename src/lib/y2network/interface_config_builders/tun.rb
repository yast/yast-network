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
    class Tun < InterfaceConfigBuilder
      def initialize(config: nil)
        super(type: InterfaceType::TUN, config: config)
      end

      # @return [Array(2)<String,String>] user and group of tunnel
      def tunnel_user_group
        [connection_config.owner, connection_config.group]
      end

      # @param [String] user owner of tunnel. Name or UID
      # @param [String] group owner of tunnel. Name or GID
      def assign_tunnel_user_group(user, group)
        connection_config.owner = user
        connection_config.group = group
      end
    end
  end
end
