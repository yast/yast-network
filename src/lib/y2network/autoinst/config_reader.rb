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
require "y2network/autoinst/interfaces_reader"
require "y2network/autoinst_profile/networking_section"
require "y2network/sysconfig/interfaces_reader"

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
        config = Yast::Lan.system_config || Y2Network::Config.new(source: :autoyast)
        config.routing = RoutingReader.new(section.routing).config if section.routing
        config.dns = DNSReader.new(section.dns).config if section.dns
        if section.interfaces
          interfaces = InterfacesReader.new(section.interfaces).config
          interfaces.each do |interface|
            # add or update system configuration, this will also create all missing interfaces
            config.add_or_update_connection_config(interface)
          end
        end

        config
      end

    private

      # Returns an interfaces reader instance
      #
      # @return [SysconfigInterfaces] Interfaces reader
      def system_interfaces
        @system_interfaces ||= Y2Network::Sysconfig::InterfacesReader.new
      end
    end
  end
end
