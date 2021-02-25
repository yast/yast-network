# Copyright (c) [2021] SUSE LLC
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
require "y2network/wireless_scanner"

module Y2Network
  # Each instance of this class represents a wireless network
  class WirelessNetwork
    attr_reader :essid, :mode, :channel, :rates, :quality, :auth_mode

    class << self
      # Returns the wireless networks found through a given interface
      #
      # If there is more than one AP, it selects the one with higher signal quality.
      #
      # @param iface_name [String] Interface to scan for networks
      def all(iface_name, cache: true)
        @all ||= {}
        return @all[iface_name] if cache && @all[iface_name]

        cells = WirelessScanner.new(iface_name).cells
        known_essids = cells.map(&:essid).uniq

        @all[iface_name] = known_essids.map do |essid|
          preferred_cell = cells
            .select { |c| c.essid == essid }
            .max_by { |c| c.quality.to_i }

          attrs = preferred_cell.to_h
          attrs.delete(:address)
          Y2Network::WirelessNetwork.new(attrs)
        end
      end
    end

    # Constructor
    def initialize(essid:, mode:, channel:, rates:, quality:, auth_mode:)
      @essid = essid
      @mode = mode
      @channel = channel
      @rates = rates
      @quality = quality
      @auth_mode = auth_mode
    end
  end
end
