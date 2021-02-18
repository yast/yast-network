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

require "y2network/wireless_mode"

module Y2Network
  # This auxiliary class holds wireless cells (access points and ad-hoc devices) information
  #
  # @todo Consider all rates properly.
  # @todo Use a rounded percentage for signal quality
  # @todo Properly parse security mechanisms
  class WirelessCell
    # @!attribute [r] address
    #   @return [String,nil] Cell MAC address
    # @!attribute [r] essid
    #   @return [String,nil] ESSID
    # @!attribute [r] mode
    #   @return [WirelessMode,nil] Wireless mode
    # @!attribute [r] channel
    #   @return [Integer,nil] Wireless channel
    # @!attribute [r] rate
    #   @return [Array<String>] Wireles rates
    # @!attribute [r] quality
    #   @return [Integer] Signal quality
    # @!attribute [r] security
    #   @return [Array<String>] Security mechanisms
    attr_reader :address, :essid, :mode, :channel, :rate, :quality, :security

    # rubocop:disable Metrics/ParameterLists
    def initialize(address:, essid:, mode:, channel:, rate:, quality:, security:)
      @address = address
      @essid = essid
      @mode = mode
      @channel = channel
      @rate = rate
      @quality = quality
      @security = security
    end
    # rubocop:enable Metrics/ParameterLists

    # Exports the cell properties to a hash
    #
    # @return [Hash<Symbol,Object>] Hash containing cell properties, using the property
    #   names as keys.
    def to_h
      { address: address, essid: essid, mode: mode, channel: channel, rate: rate,
        quality: quality, security: security }
    end
  end
end
