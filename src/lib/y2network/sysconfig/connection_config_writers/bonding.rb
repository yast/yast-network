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

require "y2network/sysconfig/connection_config_writers/base"

module Y2Network
  module Sysconfig
    module ConnectionConfigWriters
      # This class is responsible for writing the information from a ConnectionConfig::Bonding
      # object to the underlying system.
      class Bonding < Base
        # @see Y2Network::ConnectionConfigWriters::Base#update_file
        # @param conn [Y2Network::ConnectionConfig::Bonding] Configuration to write
        def update_file(conn)
          file.bonding_slaves = file_slaves(conn)
          file.bonding_module_opts = conn.options
          file.bonding_master = "yes"
        end

        # Convenience method to obtain the map of bonding slaves in the file
        # format
        #
        # @return [Hash<Integer, String>] indexed bonding slaves
        def file_slaves(conn)
          conn.slaves.each_with_index.with_object({}) { |(name, i), h| h[i] = name }
        end
      end
    end
  end
end
