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
require "y2network/dns"

module Y2Network
  module ConfigReader
    # This class is responsible of importing the AutoYast dns section
    class AutoinstDNS
      # @return [AutoinstProfile::DNSSection]
      attr_reader :section

      # @param section [AutoinstProfile::DNSSection]
      def initialize(section)
        @section = section
      end

      # Creates a new {DNS} config from the imported profile dns section
      #
      # @return [DNS] the imported {DNS} config
      def config
        options = section.class.attributes.each_with_object({}) do |attr_entry, result|
          value = section.public_send(attr_entry[:name])
          result[attr_entry[:name]] = value unless value.nil?
        end

        Y2Network::DNS.new(options)
      end
    end
  end
end
