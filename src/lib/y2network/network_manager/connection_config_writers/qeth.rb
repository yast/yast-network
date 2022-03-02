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

require "y2network/network_manager/connection_config_writers/ethernet"

module Y2Network
  module NetworkManager
    module ConnectionConfigWriters
      # This class is responsible for writing the information from a ConnectionConfig::Qeth
      # object to the underlying system.
      class Qeth < Ethernet
        # @see Y2Network::ConnectionConfigWriters::Ethernet#update_file
        # @param conn [Y2Network::ConnectionConfig::Qeth] Configuration to write
        def update_file(conn)
          super
          file.connection["s390-nettype"] = "qeth"
          file.connection["s390-options"] = options_for(conn)
          file.connection["s390-subchannels"] = conn.device_id.gsub(":", ",") if conn.device_id
        end

      private

        # Convenience method to obtain QETH specific options
        #
        # @param conn [Y2Network::ConnectionConfig::Qeth] Configuration to write
        def options_for(conn)
          "layer2=#{conn.layer2 ? 1 : 0},portno=#{conn.port_number.to_i}"
        end
      end
    end
  end
end
