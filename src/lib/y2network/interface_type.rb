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

module Y2Network
  # This class represents the interface types which are supported.
  #
  # Constants may be defined using the {define_type} method.
  class InterfaceType
    extend Yast::I18n
    include Yast::I18n

    class << self
      # @param const_name [String] Constant name
      # @param name       [String] Type name ("Ethernet", "Wireless", etc.)
      # @param short_name [String] Short name used in legacy code
      def define_type(const_name, name, short_name)
        const_set(const_name, new(name, short_name))
        all << const_get(const_name)
      end

      # Returns all the existing types
      #
      # @return [Array<InterfaceType>] Interface types
      def all
        @types ||= []
      end

      # Returns the interface type with a given short name
      #
      # @param short_name [String] Short name
      # @return [InterfaceType,nil] Interface type or nil is not found
      def from_short_name(short_name)
        all.find { |t| t.short_name == short_name }
      end
    end

    # @return [String] Returns type name
    attr_reader :name
    # @return [String] Returns type's short name
    attr_reader :short_name

    # Constructor
    #
    # @param name [String] Type name
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

    # Define types constants
    define_type "ETHERNET", N_("Ethernet"), "eth"
    define_type "WIRELESS", N_("Wireless"), "wlan"
    define_type "INFINIBAND", N_("Infiniband"), "ib"
    define_type "BONDING", N_("Bonding"), "bond"
    define_type "BRIDGE", N_("Bridge"), "br"
    define_type "DUMMY", N_("Dummy"), "dummy"
    define_type "VLAN", N_("VLAN"), "vlan"
    define_type "TUN", N_("TUN"), "tun"
    define_type "TAP", N_("TAP"), "tap"
    define_type "USB", N_("USB"), "usb"
    # s390
    define_type "QETH", N_("QETH"), "qeth"
    define_type "LCS", N_("LCS"), "lcs"
    define_type "HIPERSOCKETS", N_("HiperSockets"), "hsi"
    define_type "FICON", N_("FICON"), "ficon"
  end
end
