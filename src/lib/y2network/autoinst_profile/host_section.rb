# Copyright (c) [2020] SUSE LLC
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

require "installation/autoinst_profile/section_with_attributes"

module Y2Network
  module AutoinstProfile
    # This class represents an AutoYaST \<host> section

    class HostSection < ::Installation::AutoinstProfile::SectionWithAttributes
      # Creates an instance based on the profile representation used by the AutoYaST modules
      # (hash with nested hashes and arrays).
      #
      # @param _hash [Hash] Host section from an AutoYaST profile
      # @return [HostSection]
      def self.new_from_hashes(_hash)
        result = new
        result
      end
    end
  end
end
