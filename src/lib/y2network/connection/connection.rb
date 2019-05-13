require "y2network/interface"

module Y2Network
  module Connection
    class Connection
      # @return [Interface]
      attr_accessor :interface
      # @return [String] Bootproto (static, dhcp, none)
      attr_accessor :bootproto
      # @return [IPAddr]
      attr_accessor :ip_address
      # @return [Array<IPAddr>]
      attr_accessor :secondary_ip_addresses
      # @return [Integer]
      attr_accessor :mtu
      # @return [IPAddr]
      attr_accessor :remoteip
    end
  end
end
