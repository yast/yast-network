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
    # Configuration for TUN/TAP connections
    class Tun < Base
      # @return [String] tunnel mode ('tun' or 'tap')
      attr_accessor :mode

      # @return [String] tunnel owner (name or UID)
      attr_accessor :owner
      # @return [String] tunnel group (name or GID)
      attr_accessor :group

      def initialize
        @mode = "tun"
        @owner = ""
        @group = ""
      end

      def virtual?
        true
      end
    end
  end
end
