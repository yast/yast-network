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
require "y2network/interface_type"

module Y2Network
  # Detects type of given interface. New implementation of what was in
  # @see Yast::NetworkInterfaces.GetType
  class TypeDetector
    class << self
      # Finds type of given interface
      #
      # @param iface [String] interface name
      #
      # @return [Y2Network::InterfaceType, nil] type of given interface or nil if cannot be recognized
      def type_of(iface)
        type_by_sys(iface) || type_by_config(iface) || nil
      end

    private

      include Yast::Logger

      SYS_TYPE_NUMBERS = {
        "1"     => InterfaceType::ETHERNET,
        "24"    => InterfaceType::ETHERNET,
        "32"    => InterfaceType::INFINIBAND,
        "512"   => InterfaceType::PPP,
        "768"   => InterfaceType::IPIP,
        "769"   => InterfaceType::IPV6TNL,
        "772"   => InterfaceType::LO,
        "776"   => InterfaceType::SIT,
        "778"   => InterfaceType::GRE,
        "783"   => InterfaceType::IRDA,
        "801"   => InterfaceType::WIRELESS, # wlan_aux if needed later
        "65534" => InterfaceType::TUN
      }.freeze

      # Checks wheter iface type can be recognized by /sys filesystem
      #
      # @param iface [String] interface name
      # @return [Y2Network::InterfaceType, nil] nil when type can be recognized in /sys,
      #                                         interface type otherwise
      def type_by_sys(iface)
        raise ArgumentError, "An interface has to be given." if iface.nil?

        type_dir_path = "/sys/class/net/#{iface}/type"
        return nil if !::File.exist?(type_dir_path)

        sys_type = Yast::SCR.Read(Yast::Path.new(".target.string"), type_dir_path).to_s.strip
        type = SYS_TYPE_NUMBERS[sys_type]

        # finer detection for some types
        type = case type
        when InterfaceType::ETHERNET
          eth_type_by_sys(iface)
        when InterfaceType::INFINIBAND
          ib_type_by_sys(iface)
        end

        log.info("TypeDetector: #{iface} is of #{type} type according to /sys")

        type
      end

      # Detects a subtype of Ethernet device type according /sys or /proc content
      #
      # @example
      #   eth_type_by_sys("eth0") -> Ethernet
      #   eth_type_by_sys("bond0") -> Bonding
      #
      # @param iface [String] interface name
      # @return [Y2Network::InterfaceType] interface type
      def eth_type_by_sys(iface)
        sys_dir_path = "/sys/class/net/#{iface}"

        if ::File.exist?("#{sys_dir_path}/wireless")
          InterfaceType::WIRELESS
        elsif ::File.exist?("#{sys_dir_path}/phy80211")
          InterfaceType::WIRELESS
        elsif ::File.exist?("#{sys_dir_path}/bridge")
          InterfaceType::BRIDGE
        elsif ::File.exist?("#{sys_dir_path}/bonding")
          InterfaceType::BONDING
        elsif ::File.exist?("#{sys_dir_path}/tun_flags")
          InterfaceType::TUN
        elsif ::File.exist?("/proc/net/vlan/#{iface}")
          InterfaceType::VLAN
        elsif ::File.exist?("/sys/devices/virtual/net/#{iface}") && iface =~ /dummy/
          InterfaceType::DUMMY
        else
          InterfaceType::ETHERNET
        end
      end

      # Detects a subtype of InfiniBand device type according /sys
      #
      # @example
      #   ib_type_by_sys("ib0") -> Infiniband
      #   ib_type_by_sys("bond0") -> Bonding
      #   ib_type_by_sys("ib0.8001") -> Infiniband child
      #
      # @param iface [String] interface name
      # @return [Y2Network::InterfaceType] interface type
      def ib_type_by_sys(iface)
        sys_dir_path = "/sys/class/net/#{iface}"

        if ::File.exist?("#{sys_dir_path}/bonding")
          InterfaceType::BONDING
        elsif ::File.exist?("#{sys_dir_path}/create_child")
          InterfaceType::INFINIBAND
        else
          InterfaceType::INFINIBAND_CHILD
        end
      end

      # Checks wheter iface type can be recognized by interface configuration
      def type_by_config(_iface)
        # this part is backend specific
        raise NotImplementedError
      end
    end
  end
end
