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
require "y2network/interface"
require "y2network/config"
require "y2network/autoinst/routing_reader"
require "y2network/autoinst/dns_reader"
require "y2network/autoinst_profile/networking_section"

Yast.import "Lan"

module Y2Network
  module Autoinst
    # This class is responsible of importing Autoyast configuration
    class ConfigReader
      # @return [AutoinstProfile::NetworkingSection]
      attr_reader :section

      # Constructor
      #
      # @param section [AutoinstProfile::NetworkingSection]
      def initialize(section)
        @section = section
      end

      # @return [Y2Network::Config] Network configuration
      def config
        attrs = { source: :sysconfig }
        attrs[:interfaces] = find_interfaces
        attrs[:routing] = RoutingReader.new(section.routing).config if section.routing
        attrs[:dns] = DNSReader.new(section.dns).config if section.dns
        Y2Network::Config.new(attrs)
      end

    private

      # Find configured network interfaces
      #
      # Configured interfaces have a configuration (ifcfg file) assigned.
      #
      # @return [Array<Interface>] Detected interfaces
      # @see Yast::NetworkInterfaces.Read
      def find_interfaces
        Yast::NetworkInterfaces.Read
        # TODO: for the time being, we are just relying in the underlying stuff.
        Yast::NetworkInterfaces.List("").map do |name|
          Y2Network::Interface.new(name)
        end
      end
    end
  end
end
