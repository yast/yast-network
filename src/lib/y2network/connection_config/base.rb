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

require "y2storage"
require "y2network/interface_type"
require "y2network/boot_protocol"
require "y2network/startmode"

module Y2Network
  module ConnectionConfig
    # This class is reponsible of a connection configuration
    #
    # It holds a configuration (IP addresses, MTU, WIFI settings, etc.) that can be applied to an
    # interface. By comparison, it is the equivalent of the "Connection" concept in NetworkManager.
    # When it comes to sysconfig, a "ConnectionConfig" is defined using a "ifcfg-*" file.
    #
    # Additionally, each connection config gets an internal ID which makes easier to track changes
    # between two different {Y2Network::Config} objects. When they are copied, the same IDs are
    # kept, so it is easy to find out which connections have been added, removed or simply changed.
    class Base
      # A connection could belongs to a specific interface or not. In case of
      # no specific interface then it could be activated by the first available
      # device.
      #
      # @return [String] Connection name
      attr_accessor :name

      # @return [String, nil] Interface to apply the configuration to
      # FIXME: Maybe in the future it could be a matcher. By now we will use
      #   the interface's name.
      attr_accessor :interface

      # @return [BootProtocol] Bootproto
      attr_accessor :bootproto
      # @return [IPConfig] Primary IP configuration
      attr_accessor :ip
      # @return [Array<IPConfig>] Additional IP configurations (also known as 'aliases')
      attr_accessor :ip_aliases
      # @return [Integer, nil]
      attr_accessor :mtu
      # @return [Startmode]
      attr_accessor :startmode
      # @return [String] Connection's description (e.g., "Ethernet Card 0")
      attr_accessor :description
      # @return [String] Link layer address
      attr_accessor :lladdress
      # @return [String] configuration for ethtools when initializing
      attr_accessor :ethtool_options
      # @return [String] assigned firewall zone to interface
      attr_accessor :firewall_zone
      # @return [String] interface's hostname
      attr_accessor :hostname

      # @return [String] Connection identifier
      attr_reader :id

      # @return [Integer] Connection identifier counter
      @@last_id = 0

      # Constructor
      def initialize
        @id = @@last_id += 1
        @ip_aliases = []
        @bootproto = BootProtocol::STATIC # TODO: maybe do test query if physical interface is attached?
        @ip = IPConfig.new(IPAddress.from_string("0.0.0.0/32"))
        @startmode = Startmode.create("manual")
        @description = ""
        @ethtool_options = ""
        @firewall_zone = ""
      end

      # Compares ConnectionConfigs
      #
      # @return [Boolean] true when both connections are same
      #                   false otherwise
      def ==(other)
        return false if other.nil?
        [:name, :interface, :bootproto, :ip, :ip_aliases, :mtu, :startmode,
         :description, :lladdress, :ethtool_options, :firewall_zone, :hostname].all? do |method|
          public_send(method) == other.public_send(method)
        end
      end

      alias_method :eql?, :==

      PROPOSED_PPPOE_MTU = 1492 # suggested value for PPPoE

      # Propose reasonable defaults for given config. Useful for newly created devices.
      # @note difference between constructor and propose is that initialize should set simple defaults
      #   and propose have more tricky config that depends on env, product, etc.
      def propose
        propose_startmode
        self.mtu = PROPOSED_PPPOE_MTU if Yast::Arch.s390 && (type.lcs? || type.ethernet?)
      end

      def propose_startmode
        Yast.import "ProductFeatures"
        # see bsc#176804
        devicegraph = Y2Storage::StorageManager.instance.staging
        if devicegraph.filesystem_in_network?("/")
          @startmode = Startmode.create("nfsroot")
          log.info "startmode nfsroot"
          return
        end

        product_startmode = Yast::ProductFeatures.GetStringFeature(
          "network",
          "startmode"
        )

        startmode = case product_startmode
        when "ifplugd"
          if replace_ifplugd?
            hotplug_interface? ? "hotplug" : "auto"
          else
            product_startmode
          end
        when "auto"
          "auto"
        else
          hotplug_interface? ? "hotplug" : "auto"
        end

        @startmode = Startmode.create(startmode)
      end

      # Returns the connection type
      #
      # Any subclass could define this method is the default
      # logic does not match.
      #
      # @return [InterfaceType] Interface type
      def type
        const_name = self.class.name.split("::").last.upcase
        InterfaceType.const_get(const_name)
      end

      # Whether a connection needs a virtual device associated or not.
      #
      # @return [Boolean]
      def virtual?
        false
      end

      # Returns all IP configurations
      #
      # @return [Array<IPConfig>]
      def all_ips
        ([ip] + ip_aliases).compact
      end

      # find master from given collection of configs
      # @param configs [ConnectionConfigsCollection]
      # @return [ConnectionConfig::Bonding, ConnectionConfig::Bridge, nil] gets bridge, bonding or
      # nil in which this device in enslaved
      def find_master(configs)
        configs.find do |config|
          # TODO: what about VLAN?
          if config.type.bonding?
            config.slaves.include?(name)
          elsif config.type.bridge?
            config.ports.include?(name)
          end
        end
      end

    private

      def replace_ifplugd?
        Yast.import "Arch"

        return true if !Yast::Arch.is_laptop
        # virtual devices cannot expect any event from ifplugd
        return true if virtual?

        false
      end

      def hotplug_interface?
        # virtual interface is not hotplugable
        return false if virtual?
        # if interface is not there
        return true unless interface

        false
        # TODO: interface is just string so interface.hardware.hotplug does not work
      end
    end
  end
end
