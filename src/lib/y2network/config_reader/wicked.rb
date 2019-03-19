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
require "y2network/config"

Yast.import "NetworkInterfaces"

module Y2Network
  module ConfigReader
    # This class reads the current configuration from the system
    class Wicked
      # @return [Y2Network::Config] Network configuration
      def config
        Yast::NetworkInterfaces.Read
        Config.new(interfaces: interfaces)
      end

      def interfaces
        # TODO: for the time being, we are just relying in the underlying stuff.
        Yast::NetworkInterfaces.List("").map do |name|
          Y2Network::Interface.new(name)
        end
      end
    end
  end
end
