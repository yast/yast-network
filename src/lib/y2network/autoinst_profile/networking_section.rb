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
  module AutoinstProfile
    class NetworkingSection
      # @return [RoutingSection]
      attr_accessor :routing

      # Creates an instance based on the profile representation used by the AutoYaST modules
      # (hash with nested hashes and arrays).
      #
      # @param hash [Hash] Networking section from an AutoYaST profile
      # @return [NetworkingSection]
      def self.new_from_hashes(hash)
        result = new
        result.routing = RoutingSection.new_from_hashes(hash["routing"]) if hash["routing"]
        result
      end

      def to_hashes
        { "routing" => routing.to_hashes }
      end
    end
  end
end
