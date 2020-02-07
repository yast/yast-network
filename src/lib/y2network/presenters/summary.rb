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
    module Summary
      include Yast::Logger

      class << self
        # Config summary text for a given section
        #
        # @return [String]
        def text_for(config, section, type = "text")
          summary = self.for(config, section)
          return "" unless summary

          summary.public_send(type)
        end

        # Config summary for a given section
        #
        # @param config [Y2Network::Config]
        # @param section [String]
        def for(config, section)
          require "y2network/presenters/#{section}_summary"
          summary_class =
            case section
            when "config"
              ConfigSummary
            when "proposal"
              ProposalSummary
            when "interfaces"
              InterfacesSummary
            when "routing"
              RoutingSummary
            when "dns"
              DNSSummary
            end
          summary_class&.new(config)
        rescue LoadError => e
          log.error "Specialized summary for #{section} not found. #{e.inspect}"
          nil
        end
      end
    end
  end
end
