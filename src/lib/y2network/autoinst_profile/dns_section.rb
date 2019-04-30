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
    # This class represents an AutoYaST <dns> section under <networking>
    #
    #  <dns>
    #    <dhcp_hostname config:type="boolean">true</dhcp_hostname>
    #    <hostname>linux</hostname>
    #    <nameservers config:type="list">
    #      <nameserver>192.168.122.1</nameserver>
    #      <nameserver>10.0.0.2</nameserver>
    #    </nameservers>
    #    <resolv_conf_policy>auto</resolv_conf_policy>
    #    <searchlist config:type="list">
    #      <search>example.net</search>
    #      <search>example.org</search>
    #    </searchlist>
    #    <write_hostname config:type="boolean">false</write_hostname>
    #  </dns>
    class DNSSection < Y2Network::AutoinstProfile::SectionWithAttributes
      def self.attributes
        [
          { name: :dhcp_hostname },
          { name: :hostname },
          { name: :nameservers },
          { name: :resolv_conf_policy },
          { name: :searchlist },
          { name: :write_hostname }
        ]
      end

      define_attr_accessors

      def self.new_from_network(dns)
        result = new
        initialized = result.init_from_network(dns)
        initialized ? result : nil
      end

      # Constructor
      def initialize(*_args)
        super
        @nameservers = []
        @searchlist = []
      end

      # Method used by {.new_from_network} to populate the attributes when cloning DNS options
      #
      # @param dns [Y2Network::DNS] DNS settings
      # @return [Boolean] Result true on success or false otherwise
      def init_from_network(dns)
        @dhcp_hostname = dns.dhcp_hostname
        @hostname = dns.hostname
        @nameservers = dns.name_servers.map(&:to_s)
        @resolv_conf_policy = dns.resolv_conf_policy
        @searchlist = dns.search_domains
        @write_hostname = dns.hostname_to_hosts
        true
      end
    end
  end
end
