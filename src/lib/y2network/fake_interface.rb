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

require "y2network/interface"

module Y2Network
  # A physical interface that is not plugged in.
  class FakeInterface < Interface
    class << self
      # Build connection
      #
      # @todo Would be possible to get the name from the connection?
      #
      # @param name [String] Interface name
      # @param conn [ConnectionConfig] Connection configuration related to the
      #   network interface
      def from_connection(name, conn)
        new(name, type: conn.type)
      end
    end
  end
end
