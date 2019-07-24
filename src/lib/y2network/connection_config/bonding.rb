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
require "y2network/fake_interface"

module Y2Network
  module ConnectionConfig
    # Configuration for bonding connections
    #
    # @see https://www.kernel.org/doc/Documentation/networking/bonding.txt
    class Bonding < Base
      # @return [Array<Interface>]
      attr_accessor :slaves
      # @return [String] bond driver options
      attr_accessor :options

      def initialize
        @slaves = []
        @options = ""
      end

      # @see Y2Network::InterfacesCollection
      #
      # @param interfaces [Y2Network::InterfacesCollection]
      def update_interfaces!(interfaces)
        return if slaves.empty?
        new_slaves = []

        slaves.each do |index, slave|
          alternative = interfaces.by_name(slave)
          unless alternative
            alternative = Y2Network::FakeInterface.new(slave)
            interfaces << alternative
          end
          slaves[index] = alternative
        end

        slaves = new_slaves

        nil
      end

      def virtual?
        true
      end
    end
  end
end
