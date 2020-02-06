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
Yast.import "Summary"
Yast.import "NetworkInterfaces"

module Y2Network
  module Presenters
    # This class converts a DNS configuration object into a string to be used
    # in an AutoYaST summary.
    class DNSSummary
      extend Forwardable
      include Yast::I18n

      # @return [Y2Network::Config]
      attr_reader :config

      def_delegators :@config, :hostname, :dns

      # Constructor
      #
      # @param config [Y2Network::Config]
      def initialize(config)
        textdomain "network"
        @config = config
      end

      def text
        summary = add_hostname("")
        summary = add_nameservers(summary)
        summary = add_searchlist(summary)
        "<ul>#{summary}\n</ul>"
      end

    private

      def dhcp_hostname?
        return false unless hostname.dhcp_hostname
        return false unless config.connections.any?(&:dhcp?)

        hostname.dhcp_hostname != :none
      end

      def add_hostname(summary)
        hostname_str = format_hostname
        return summary unless hostname_str

        Yast::Summary.AddListItem(summary, hostname_str)
      end

      def format_hostname
        if dhcp_hostname?
          _("Hostname: Set by DHCP")
        elsif hostname.hostname && !hostname.hostname.empty?
          format(_("Hostname: %s"), hostname.hostname)
        end
      end

      def add_nameservers(summary)
        return summary if dns.nameservers.empty?

        item = format(_("Name Servers: %s"), dns.nameservers.map(&:to_s).join(", "))
        Yast::Summary.AddListItem(summary, item)
      end

      def add_searchlist(summary)
        return summary if dns.searchlist.empty?

        item = format(_("Search List: %s"), dns.searchlist.join(", "))
        Yast::Summary.AddListItem(summary, item)
      end
    end
  end
end
