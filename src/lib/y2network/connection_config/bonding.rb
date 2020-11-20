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
    # Configuration for bonding connections
    #
    # @see https://www.kernel.org/doc/Documentation/networking/bonding.txt
    class Bonding < Base
      # @return [Array<String>]
      attr_accessor :slaves
      # @return [String] bond driver options
      attr_accessor :options

      def initialize
        super()
        @slaves = []
        @options = "mode=active-backup miimon=100"
      end

      def ==(other)
        return false unless super

        options == other.options && ((slaves - other.slaves) + (other.slaves - slaves)).empty?
      end

      alias_method :eql?, :==

      def virtual?
        true
      end
    end
  end
end
