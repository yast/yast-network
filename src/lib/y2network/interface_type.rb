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
      # @param name       [String] Type name ("Ethernet", "Wireless", etc.)
      # @param short_name [String] Short name used in legacy code
      def define_type(name, short_name)
        const_name = name.upcase
        const_set(const_name, new(name, short_name))
        all << const_get(const_name)
      end

      # Returns all the existing types
      #
      # @return [Array<InterfaceType>] Interface types
      def all
        @types ||= InterfaceType.constants.map { |c| InterfaceType.const_get(c) }
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
    # @param short_name [String] short name as is used for prefixing of
    #   interface name (e.g. bond, eth or wlan)
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

    # Returns name for specialized class for this type e.g. for reader, write or builder
    # @return [String]
    def class_name
      name.capitalize
    end

    # Returns name for file without suffix for this type e.g. for reader, write or builder
    # @return [String]
    def file_name
      name.downcase
    end

    # Ethernet card, integrated or attached
    ETHERNET = new(N_("Ethernet"), "eth")
    # Wireless card, integrated or attached
    WIRELESS = new(N_("Wireless"), "wlan")
    # Infiniband card
    INFINIBAND = new(N_("Infiniband"), "ib")
    # Bonding device
    BONDING = new(N_("Bonding"), "bond")
    # bridge device
    BRIDGE = new(N_("Bridge"), "br")
    # virtual dummy device provided by dummy kernel module
    DUMMY = new(N_("Dummy"), "dummy")
    # Virtual LAN
    VLAN = new(N_("VLAN"), "vlan")
    # TUN virtual device provided by kernel, operates on layer3 carrying IP packagets
    TUN = new(N_("TUN"), "tun")
    # TAP virtual device provided by kernel, operates on layer2 carrying Ethernet frames
    TAP = new(N_("TAP"), "tap")
    # ethernet over usb device provided by usbnet kernel module. Do not confuse
    # with ethernet card attached to USB slot as it is common ETHERNET type.
    USB = new(N_("USB"), "usb")
    # device using qeth device driver for s390. Can operate on layer2 or layer3.
    QETH = new(N_("QETH"), "qeth")
    # LAN-Channel-Station (LCS) network devices. S390 specific.
    LCS = new(N_("LCS"), "lcs")
    # HiperSockets s390 network device
    HIPERSOCKETS = new(N_("HiperSockets"), "hsi")
    # FICON-attached direct access storage devices. s390 specific
    FICON = new(N_("FICON"), "ficon")
  end
end
