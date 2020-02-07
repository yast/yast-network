# Copyright (c) [2020] SUSE LLC
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
require "y2network/presenters/proposal_summary"
require "y2network/presenters/interfaces_summary"
require "y2network/presenters/dns_summary"
require "y2network/presenters/routing_summary"

module Y2Network
  module Presenters
    class ProposalSummary
      include Yast::I18n
      # @return [Y2Network::Config]
      attr_reader :config

      # Constructor
      #
      # @param config [Y2Network::Config]
      def initialize(config)
        @config = config
      end

      # Network proposal html summary
      #
      # @return [String]
      def text
        output = "<ul>"
        output << list_entry_for(_("Interfaces"), interfaces_summary.proposal_text)
        output << list_entry_for(_("Hostname / DNS"), dns_summary.text)
        output << list_entry_for(_("Routing"), routing_summary.text)
        output << "</ul>"

        output
      end

      # Basic information about interfaces configuration for the one line
      # network proposal plain text summary.
      #
      # @return [String]
      def one_line_text
        interfaces_summary.one_line_text
      end

    private

      def list_entry_for(title, content)
        "<li>" + title + "</li>" + content
      end

      def interfaces_summary
        @interfaces_summary ||= Summary.for(config, "interfaces")
      end

      def routing_summary
        @routing_summary ||= Summary.for(config, "routing")
      end

      def dns_summary
        @dns_summary ||= Summary.for(config, "dns")
      end
    end
  end
end
