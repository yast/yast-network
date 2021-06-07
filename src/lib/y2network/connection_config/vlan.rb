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

require "y2network/connection_config/base"

module Y2Network
  module ConnectionConfig
    # Configuration for vlan connections
    class Vlan < Base
      # FIXME: By now it will be just the interface name although in NM it
      #   could be a ifname, UUID or even a MAC address.
      # TODO: consider using Interface instead of plain string?
      #
      # @return [String] the real interface associated with the vlan
      attr_accessor :parent_device
      # @return [Integer, nil]
      attr_accessor :vlan_id

      eql_attr :parent_device, :vlan_id

      # @see Y2Network::ConnectionConfig::Base#virtual?
      def virtual?
        true
      end
    end
  end
end
