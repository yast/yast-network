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
require "ipaddr"
Yast.import "IP"

module Y2Network
  module Autoinst
    # This class is responsible of importing the AutoYast dns section
    class DNSReader
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
        Y2Network::DNS.new(
          dhcp_hostname:      section.dhcp_hostname,
          hostname:           section.hostname,
          nameservers:        valid_ips(section.nameservers),
          resolv_conf_policy: section.resolv_conf_policy,
          searchlist:         section.searchlist
        )
      end

    private

      # Given a list of IPs in string form, builds a list of valid IPAddr objects
      #
      # Invalid IPs are filtered out.
      #
      # @param ips [Array<String>]
      # @return [Array<IPAddr>]
      def valid_ips(ips)
        ips.each_with_object([]) do |ip_str, all|
          all << IPAddr.new(ip_str) if Yast::IP.Check(ip_str)
        end
      end
    end
  end
end
