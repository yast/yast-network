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
require "installation/auto_client"
require "y2network/config"
require "y2network/routing"
require "y2network/autoinst_profile/networking_section"
require "y2network/config_reader/routing_autoyast"

Yast.import "NetworkInterfaces"
Yast.import "Lan"

module Y2Network
  module Clients
    # This class is reponsible of the autoinstallation routing configuration.
    class RoutingAuto < ::Installation::AutoClient
      include Yast::I18n
      include Yast::Logger

      class << self
        # @return [Boolean] whether the AutoYaST configuration has been
        # modified or not
        attr_accessor :changed
      end

      # Constructor
      def initialize
        textdomain "network"
      end

      # Import routing configuration
      #
      # @param profile [Hash] routing profile section to be imported
      # @return [Boolean]
      def import(profile = {})
        return false unless config

        routing_section = Y2Network::AutoinstProfile::RoutingSection.new_from_hashes(profile)
        config.routing = Y2Network::ConfigReader::RoutingAutoyast.new(routing_section).config
        modified!
      end

      # Export routing configuration
      #
      # @return [Hash] current routing configuration
      def export
        # TODO: should use a presenter
        routing = Y2Network::AutoinstProfile::RoutingSection.new_from_network(config.routing)
        routing.to_hashes
      end

      # Reset changes
      def reset
        self.class.changed = false
        config.routing = nil
      end

      def change
        log.info "Pending implementation"
      end

      def modified
        !!self.class.changed
      end

      def modified!
        self.class.changed = true
      end

    private

      # Convenience method to obtain current network configuration
      #
      # @return [Config] current network config
      def config
        Yast::Lan.find_config(id: "yast")
      end
    end
  end
end
