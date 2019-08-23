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

Yast.import "LanItems"

module Y2Network
  module InterfaceConfigBuilders
    class Infiniband < InterfaceConfigBuilder
      def initialize(config: nil)
        super(type: InterfaceType::INFINIBAND, config: config)
      end

      # @return [String] ipoib mode configuration
      attr_writer :ipoib_mode

      # Returns current value of infiniband mode
      #
      # @return [String] particular mode or "default" when not set
      def ipoib_mode
        @ipoib_mode ||= if [nil, ""].include?(@config["IPOIB_MODE"])
          "default"
        else
          @config["IPOIB_MODE"]
        end
      end

      # (see Y2Network::InterfaceConfigBuilder#save)
      #
      # In case of config builder for Ib interface type it sets infiniband's
      # mode to reasonable default when not set explicitly.
      def save
        super

        @config["IPOIB_MODE"] = ipoib_mode == "default" ? nil : ipoib_mode

        nil
      end
    end
  end
end
