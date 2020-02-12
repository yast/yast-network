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

module Y2Network
  module Presenters
    # This class is responsible of creating text summaries for the given
    # Y2Network::Config.
    class ConfigSummary
      # @return [Y2Network::Config]
      attr_reader :config

      # Constructor
      #
      # @param config [Y2Network::Config]
      def initialize(config)
        @config = config
      end

      # Network config RichText summary
      #
      # @return [String]
      def text
        "#{interfaces_summary.text}#{dns_summary.text}#{routing_summary.text}"
      end

    private

      # Convenience method to obtain the current config interfaces summary
      def interfaces_summary
        @interfaces_summary ||= Summary.for(config, "interfaces")
      end

      # Convenience method to obtain the current config routing summary
      def routing_summary
        @routing_summary ||= Summary.for(config, "routing")
      end

      # Convenience method to obtain the current config dns summary
      def dns_summary
        @dns_summary ||= Summary.for(config, "dns")
      end
    end
  end
end
