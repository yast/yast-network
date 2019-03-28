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

module Y2Network
  module Presenters
    # This class converts a routing configuration object into a hash to be used
    # in an AutoYaST summary
    class RoutingSummary
      # @return [Y2Network::Config]
      attr_reader :config

      # Constructor
      #
      # @param config [Y2Network::Config] Network configuration to represent
      def initialize(config)
        @config = config
      end

      # Returns the summary of network configuration settings in text form
      #
      # @param mode [Symbol] Summary mode (:summary or :proposal)
      # @return [String]
      def text(mode:)
        "Config summary in #{mode} mode"
      end
    end
  end
end
