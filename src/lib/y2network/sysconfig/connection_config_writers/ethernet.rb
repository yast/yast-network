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
      # This class is responsible for writing the information from a ConnectionConfig::Ethernet
      # object to the underlying system.
      class Ethernet < Base
        # Writes connection information to the interface configuration file
        #
        # @param conn [Y2Network::ConnectionConfig::Base] Configuration to write
        def write(conn)
          file.bootproto = conn.bootproto
          file.name = conn.description
          file.startmode = conn.startmode
          write_ip_configs(conn.ip_configs)
        end
      end
    end
  end
end
