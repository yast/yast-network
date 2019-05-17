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

require "y2network/connection_config/base"

module Y2Network
  module ConnectionConfig
    # Configuration for wireless connections
    class Wireless < Base
      # wireless options
      #
      # FIXME: Consider an enum
      # @return [String] (Ad-hoc, Managed, Master)
      attr_accessor :mode
      # @return [String]
      attr_accessor :essid
      # @return [Integer]
      attr_accessor :nwid
      # FIXME: Consider an enum
      # @return [String] (no-encription, open, sharedkey, eap, psk)
      attr_accessor :auth_mode
      # FIXME: Consider moving keys to different classes.
      # @return [String]
      attr_accessor :wpa_psk
      # @return [Integer]
      attr_accessor :key_length
      # @return [Array<String>] WEP keys
      attr_accessor :keys
      # @return [String] default WEP key
      attr_accessor :default_key
      # @return [String]
      attr_accessor :nick

      # @return [Hash<String, String>]
      attr_accessor :wpa_eap
      # @return [Integer]
      attr_accessor :channel
      # @return [Integer]
      attr_accessor :frequency
      # @return [Integer]
      attr_accessor :bitrate
      # @return [String]
      attr_accessor :accesspoint
      # @return [Boolean]
      attr_accessor :power
      # FIXME: Consider an enum
      # @return [Integer] (0, 1, 2)
      attr_accessor :ap_scanmode
    end
  end
end
