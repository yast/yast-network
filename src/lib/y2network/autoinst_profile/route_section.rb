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

require "y2network/autoinst_profile/section_with_attributes"

module Y2Network
  module AutoinstProfile
    # This class represents an AutoYaST <route> section under <routing>
    #
    #  <route>
    #    <destination>192.168.1.0</destination>
    #    <device>eth0</device>
    #    <extrapara>foo</extrapara>
    #    <gateway>-</gateway>
    #    <netmask>-</netmask>
    #  </route>
    #
    # @see RoutingSection
    class RouteSection < SectionWithAttributes
      def self.attributes
        [
          { name: :destination },
          { name: :device },
          { name: :extrapara },
          { name: :gateway },
          { name: :netmask }
        ]
      end

      define_attr_accessors

      # @!attribute destination
      #  @return [String] Route destination

      # @!attribute device
      #  @return [String] Interface name

      # @!attribute extrapara
      #  @return [String] Route options

      # @!attribute gateway
      #  @return [String] Route gateway

      # @!attribute netmask
      #  @return [String] Netmask
    end
  end
end
