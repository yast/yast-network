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

require "installation/autoinst_profile/section_with_attributes"
require "y2network/autoinst_profile/dns_section"
require "y2network/autoinst_profile/interfaces_section"
require "y2network/autoinst_profile/routing_section"
require "y2network/autoinst_profile/udev_rules_section"
require "y2network/autoinst_profile/s390_devices_section"

module Y2Network
  module AutoinstProfile
    # This class represents an AutoYaST \<networking> section
    #
    #  <networking>
    #    <routing>
    #      <!-- the routing configuration -->
    #    </routing>
    #  </networking>
    #
    # @see RoutingSection
    class NetworkingSection < Installation::AutoinstProfile::SectionWithAttributes
      # @return [Boolean]
      attr_accessor :setup_before_proposal
      # @return [Boolean]
      attr_accessor :start_immediately
      # @return [Boolean]
      attr_accessor :keep_install_network
      # @return [Integer]
      attr_accessor :strict_ip_check_timeout

      # @return [RoutingSection]
      attr_accessor :routing
      # @return [DNSSection]
      attr_accessor :dns
      # @return [InterfacesSection]
      attr_accessor :interfaces
      # @return [UdevRulesSection]
      attr_accessor :udev_rules
      # @return [S390DevicesSection]
      attr_accessor :s390_devices
      # @return [Boolean]
      attr_accessor :managed

      # Creates an instance based on the profile representation used by the AutoYaST modules
      # (hash with nested hashes and arrays).
      #
      # @param hash [Hash] Networking section from an AutoYaST profile
      # @return [NetworkingSection]
      def self.new_from_hashes(hash)
        result = new
        result.managed = hash["managed"]
        result.setup_before_proposal = hash.fetch("setup_before_proposal", false)
        result.start_immediately = hash.fetch("start_immediately", false)
        result.keep_install_network = hash.fetch("keep_install_network", true)
        result.strict_ip_check_timeout = hash.fetch("strict_ip_check_timeout", -1)
        result.routing = RoutingSection.new_from_hashes(hash["routing"], result) if hash["routing"]
        result.dns = DNSSection.new_from_hashes(hash["dns"], result) if hash["dns"]
        if hash["interfaces"]
          result.interfaces = InterfacesSection.new_from_hashes(hash["interfaces"], result)
        end
        if hash["net-udev"]
          result.udev_rules = UdevRulesSection.new_from_hashes(hash["net-udev"], result)
        end
        if hash["s390-devices"]
          result.s390_devices = S390DevicesSection.new_from_hashes(hash["s390-devices"], result)
        end
        result
      end

      # Creates an instance based on the network configuration representation
      #
      # @param config [Y2Network::Config]
      # @return [NetworkingSection]
      def self.new_from_network(config)
        result = new
        return result unless config

        result.managed = config.backend?(:network_manager)
        build_dns = config.dns || config.hostname

        result.routing = RoutingSection.new_from_network(config.routing) if config.routing
        result.dns = DNSSection.new_from_network(config.dns, config.hostname) if build_dns
        result.interfaces = InterfacesSection.new_from_network(config.connections, result)
        result.udev_rules = UdevRulesSection.new_from_network(config.interfaces)
        result.s390_devices = S390DevicesSection.new_from_network(config.connections)
        result
      end

      # Export the section to a hash so it might be used when cloning the system
      #
      # @return [Hash]
      def to_hashes
        result = {}
        result["dns"] = dns&.to_hashes || {}
        unless managed
          result["routing"] = routing&.to_hashes || {}
          result["net-udev"] = udev_rules&.udev_rules&.map(&:to_hashes) || []
          result["interfaces"] = interfaces&.interfaces&.map(&:to_hashes) || []
          result["s390-devices"] = s390_devices&.to_hashes&.fetch("devices", []) || []
        end

        result.keys.each { |k| result.delete(k) if result[k].empty? }
        result["managed"] = true if managed
        result
      end
    end
  end
end
