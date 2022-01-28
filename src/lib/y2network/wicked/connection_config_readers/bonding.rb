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

require "y2network/wicked/connection_config_readers/base"

module Y2Network
  module Wicked
    module ConnectionConfigReaders
      # This class is able to build a ConnectionConfig::Bonding object given a
      # SysconfigInterfaceFile object.
      class Bonding < Base
        # @see Y2Network::Wicked::ConnectionConfigReaders::Base#update_connection_config
        def update_connection_config(conn)
          conn.ports = ports
          conn.options = file.bonding_module_opts
        end

      private

        # Convenience method to obtain the bonding ports defined in the file
        #
        # @return [Array<String>] bonding ports defined in the file
        def ports
          (file.bonding_slaves || {}).sort_by { |k, _v| k.to_i }.to_h.values
        end
      end
    end
  end
end
