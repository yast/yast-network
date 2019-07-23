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

require "y2network/sysconfig/connection_config_readers/base"
require "y2network/connection_config/ethernet"
require "y2network/boot_protocol"
require "y2network/startmode"

module Y2Network
  module Sysconfig
    module ConnectionConfigReaders
      # This class is able to build a ConnectionConfig::Ethernet object given a
      # Sysconfig::InterfaceFile object.
      class Ethernet < Base
      private

        # @return [Y2Network::ConnectionConfig::Ethernet]
        # @see Y2Network::Sysconfig::ConnectionConfigReaders::Base#connection_class
        def connection_class
          Y2Network::ConnectionConfig::Ethernet
        end

        # @see Y2Network::Sysconfig::ConnectionConfigReaders::Base#update_connection_config
        def update_connection_config(_conn)
        end
      end
    end
  end
end
