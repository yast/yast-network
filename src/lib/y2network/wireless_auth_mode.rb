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

module Y2Network
  class WirelessAuthMode
    extend Yast::I18n
    include Yast::I18n

    class << self
      # Returns all the existing modes
      #
      # @return [Array<WirelessAuthMode>] Wireless authentication modes
      def all
        @all ||= WirelessAuthMode.constants
          .map { |c| WirelessAuthMode.const_get(c) }
          .select { |c| c.is_a?(WirelessAuthMode) }
      end
    end

    # @!attribute [r] name
    #   @return [String] Wireless authentication mode name
    # @!attribute [r] short_name
    #   @return [String] Wireless mode short name (to be used in configuration files)
    attr_reader :name, :short_name

    # Constructor
    #
    # @param name [String] Wireless mode name
    # @param short_name [String] Wireles mode short name (e.g., "ad-hoc")
    def initialize(name, short_name)
      textdomain "network"
      @name = name
      @short_name = short_name
    end

    # Returns the translated name
    #
    # @return [String]
    def to_human_string
      _(name)
    end

    NONE = new(N_("No Encryption"))
    WEP_OPEN = new(N_("WEP - Open"), "open")
    WEP_SHARED = new(N_("WEP - Shared Key"), "shared")
    WPA_PSK = new(N_("WPA-PSK (\"home\")"), "psk")
    WPA_EAP = new(N_("WPA-EAP (\"enterprise\")"), "eap")
  end
end
