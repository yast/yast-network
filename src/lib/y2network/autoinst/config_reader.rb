# Copyright c) [2019] SUSE LLC
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
require "y2network/autoinst/hostname_reader"
require "y2network/autoinst/interfaces_reader"
require "y2network/autoinst/udev_rules_reader"
require "y2network/autoinst_profile/networking_section"
require "y2network/wicked/interfaces_reader"
require "y2network/issues_result"

Yast.import "Stage"

module Y2Network
  module Autoinst
    # This class is responsible of importing Autoyast configuration
    class ConfigReader
      # @return [AutoinstProfile::NetworkingSection]
      attr_reader :section

      # Constructor
      #
      # @param section [AutoinstProfile::NetworkingSection]
      # @param original_config [Config] system configuration
      def initialize(section, original_config)
        @section = section
        @original_config = original_config
      end

      # @return [IssuesResult] Network configuration
      def read
        config = Y2Network::Config.new(source: :autoinst)
        # We need the current interfaces in order to rewrite the config
        # properly but the rest should be imported from the profile
        config.interfaces = @original_config.interfaces.copy
        # merge devices definitions obtained from inst-sys
        # and those which were read from AY profile. bnc#874259
        config.connections = @original_config.connections.copy if keep_configured_network?

        # apply at first udev rules, so interfaces names are correct
        UdevRulesReader.new(section.udev_rules).apply(config) if section.udev_rules
        config.routing = RoutingReader.new(section.routing).config if section.routing
        config.dns = DNSReader.new(section.dns).config if section.dns
        config.hostname = HostnameReader.new(section.dns).config if section.dns

        if section.interfaces
          interfaces = InterfacesReader.new(section.interfaces).config
          interfaces.each do |interface|
            # add or update system configuration, this will also create all missing interfaces
            config.add_or_update_connection_config(interface)
          end
        end

        config.backend = ay_backend

        Y2Network::IssuesResult.new(config)
      end

    private

      # Convenience method to check whether the configured network should be
      # kept or not (by default returns true)
      #
      # @return [Boolean]
      def keep_configured_network?
        section.keep_install_network != false
      end

      def ay_backend
        # During the first stage of an autoinstallation we are not able to
        # switch to another backend and in case of setup_before_proposal the
        # config should be written to the inst-sys (:wicked).
        return :wicked if Yast::Stage.initial
        return section.backend.to_sym unless [nil, ""].include?(section.backend)

        section.managed ? :network_manager : :wicked
      end
    end
  end
end
