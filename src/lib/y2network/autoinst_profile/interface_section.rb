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

require "y2network/autoinst_profile/section_with_attributes"

module Y2Network
  module AutoinstProfile
    # This class represents an AutoYaST <interface> section under <interfaces>
    #
    #  <interface>
    #    <bootproto>static</bootproto>
    #    <broadcast>127.255.255.255</broadcast>
    #    <device>lo</device>
    #    <firewall>no</firewall>
    #    <ipaddr>127.0.0.1</ipaddr>
    #    <netmask>255.0.0.0</netmask>
    #    <network>127.0.0.0</network>
    #    <prefixlen>8</prefixlen>
    #    <startmode>nfsroot</startmode>
    #    <usercontrol>no</usercontrol>
    #  </interface>
    #
    # @see InterfacesSection
    class InterfaceSection < SectionWithAttributes
      def self.attributes
        [
          { name: :bootproto },
          { name: :broadcast },
          { name: :device },
          { name: :name }, # has precedence over device
          { name: :ipaddr },
          { name: :remote_ipaddr },
          { name: :netmask },
          { name: :network }, # TODO: what it is? looks like ipaddr with applied prefix
          { name: :prefixlen }, # has precedence over netmask
          { name: :startmode },
          { name: :ifplugd_priority },
          { name: :usercontrol }, # no longer used, ignored
          { name: :dhclient_set_hostname },
          { name: :bonding_master },
          { name: :bonding_slave0 },
          { name: :bonding_slave1 },
          { name: :bonding_slave2 },
          { name: :bonding_slave3 },
          { name: :bonding_slave4 },
          { name: :bonding_slave5 },
          { name: :bonding_slave6 },
          { name: :bonding_slave7 },
          { name: :bonding_slave8 },
          { name: :bonding_slave9 },
          { name: :bonding_module_opts },
          { name: :aliases },
          { name: :mtu },
          { name: :ethtool_options },
          { name: :wireless }, # TODO: what it is?
          { name: :firewall }, # yes/no
          { name: :zone }, # firewall zone
          { name: :dhclient_set_down_link }, # TODO: what it do?
          { name: :dhclient_set_default_route }, # TODO: what it do?
          { name: :vlan_id },
          { name: :etherdevice },
          { name: :bridge }, # yes/no # why? bridge always have to be yes
          { name: :bridge_ports },
          { name: :bridge_stp }, # on/off
          { name: :bridge_forward_delay },
          { name: :wireless_ap },
          { name: :wireless_auth_mode },
          { name: :wireless_bitrate },
          { name: :wireless_ca_cert },
          { name: :wireless_channel },
          { name: :wireless_client_cert },
          { name: :wireless_client_key },
          { name: :wireless_client_key_password },
          { name: :wireless_default_key },
          { name: :wireless_eap_auth },
          { name: :wireless_eap_mode },
          { name: :wireless_essid },
          { name: :wireless_frequency },
          { name: :wireless_key }, # default wep key
          { name: :wireless_key0 },
          { name: :wireless_key1 },
          { name: :wireless_key2 },
          { name: :wireless_key3 },
          { name: :wireless_key_length },
          { name: :wireless_mode },
          { name: :wireless_nick },
          { name: :wireless_nwid },
          { name: :wireless_peap_version },
          { name: :wireless_power },
          { name: :wireless_wpa_anonid },
          { name: :wireless_wpa_identity },
          { name: :wireless_wpa_password },
          { name: :wireless_wpa_psk }
        ]
      end

      define_attr_accessors

      # @!attribute bootproto
      #  @return [String] boot protocol

      # @!attribute broadcast
      #  @return [String] broadcast ip address.

      # @!attribute device
      #  @return [String] device name. Deprecated. `name` should be used instead.

      # @!attribute name
      #  @return [String] device name.

      # @!attribute ipaddr
      #  @return [String] ip address.

      # @!attribute remote_ipaddr
      #  @return [String] remote ip address for ptp connections.

      # @!attribute netmask
      #  @return [String] network mask. Deprecated `prefix` should be used instead.

      # @!attribute network
      #  @return [String] network ip after prefix applied. Deprecated as it can
      #    be computed from ipaddr and prefixlen.

      # @!attribute prefixlen
      #  @return [String] size of network prefix.

      # @!attribute startmode
      #  @return [String] when to start network.

      # @!attribute ifplugd_priority
      #  @return [String] priority for ifplugd startmode.

      # @!attribute usercontrol
      #  @return [String] no clue what it means, but it is ignored now.

      # @!attribute dhclient_set_hostname
      #  @return [String] if dhcp sets hostname. "yes" if sets

      # @!attribute bonding_master
      #  @return [String] ???

      # @!attribute bonding_slaveX
      #  @return [String] bonding slave on position X

      # @!attribute bonding_module_opts
      #  @return [String] bonding options

      # @!attribute aliases
      # @example xml section for aliases from SLE15
      #   <aliases>
      #     <alias0>
      #       <IPADDR>10.100.0.1</IPADDR>
      #       <LABEL>test</LABEL>
      #       <NETMASK>255.255.255.0</NETMASK>
      #       <PREFIXLEN>24</PREFIXLEN>
      #     </alias0>
      #     <alias1>
      #       <IPADDR>10.100.0.2</IPADDR>
      #       <LABEL>test2</LABEL>
      #       <NETMASK>255.255.255.0</NETMASK>
      #       <PREFIXLEN>24</PREFIXLEN>
      #     </alias1>
      #   </aliases>
      #
      # @return [Object] aliases for interface

      # @!attribute mtu
      #  @return [String] MTU for interface

      # @!attribute ethtool_options
      #  @return [String] options for ethtool

      # @!attribute wireless
      #  @return [String] ???

      # @!attribute firewall
      #  @return [String] ???

      # @!attribute zone
      #  @return [String] firewall zone to which interface belongs

      # @!attribute dhclient_set_down_link
      #  @return [String] ???

      # @!attribute dhclient_set_default_route
      #  @return [String] ???

      # @!attribute vlan_id
      #  @return [String] id of vlan

      # @!attribute etherdevice
      #  @return [String] parent device of vlan

      # @!attribute bridge
      #  @return [String] "yes" if device is bridge

      # @!attribute bridge_ports
      #  @return [String] bridge ports separated by space

      # @!attribute bridge_stp
      #  @return [String] "on" if stp is enabled

      # @!attribute bridge_forward_delay
      #  @return [String] time of delay

      # @!attribute wireless_ap
      # @!attribute wireless_auth_mode
      # @!attribute wireless_bitrate
      # @!attribute wireless_ca_cert
      # @!attribute wireless_channel
      # @!attribute wireless_client_cert
      # @!attribute wireless_client_key
      # @!attribute wireless_client_key_password
      # @!attribute wireless_default_key
      # @!attribute wireless_eap_auth
      # @!attribute wireless_eap_mode
      # @!attribute wireless_essid
      # @!attribute wireless_frequency
      # @!attribute wireless_key
      # @!attribute wireless_keyX
      #  @return [String] key on position X
      # @!attribute wireless_key_length
      # @!attribute wireless_mode
      # @!attribute wireless_nick
      # @!attribute wireless_nwid
      # @!attribute wireless_peap_version
      # @!attribute wireless_power
      # @!attribute wireless_wpa_anonid
      # @!attribute wireless_wpa_identity
      # @!attribute wireless_wpa_password
      # @!attribute wireless_wpa_psk

      # Clones a network interface into an AutoYaST interface section
      #
      # @param connection_config [Y2Network::ConnectionConfig] Network connection config
      # @return [InterfacesSection]
      def self.new_from_network(connection_config)
        result = new
        result.init_from_config(connection_config)
        result
      end

      def initialize(*_args)
        super

        self.class.attributes.each do |attr|
          # init everything to empty string
          public_send(:"#{attr[:name]}=", "")
        end

        self.aliases = {}
      end

      # Overwrite base method to load also nested aliases
      def init_from_hashes(hash)
        super

        self.aliases = hash["aliases"] if hash["aliases"]
      end

      # Method used by {.new_from_network} to populate the attributes when cloning a network
      # interface
      #
      # @param config [Y2Network::ConnectionConfig]
      # @return [Boolean]
      def init_from_config(config)
        @bootproto = config.bootproto.name
        @name = config.name
        if config.bootproto == BootProtocol::STATIC && config.ip
          @ipaddr = config.ip.address.address.to_s
          @prefixlen = config.ip.address.prefix.to_s
          @remote_ipaddr = config.ip.remote_address.address.to_s if config.ip.remote_address
          @broadcast = config.ip.broadcast.address.to_s if config.ip.broadcast
        end

        @startmode = config.startmode.name
        @ifplugd_priority = config.startmode.priority.to_s if config.startmode.name == "ifplugd"
        @mtu = config.mtu.to_s if config.mtu
        @ethtool_options = config.ethtool_options if config.ethtool_options
        @zone = config.firewall_zone.to_s
        # see aliases for example output
        @aliases = config.ip_aliases.each_with_index.each_with_object({}) do |(ip, index), res|
          res["alias#{index}"] = {
            "IPADDR"    => ip.address.address.to_s,
            "LABEL"     => ip.label || "",
            "PREFIXLEN" => ip.address.prefix.to_s
          }
        end

        case config
        when ConnectionConfig::Vlan
          @vlan_id = config.vlan_id.to_s
          @etherdevice = config.parent_device
        when ConnectionConfig::Bridge
          @bridge = "yes"
          @bridge_ports = config.ports.join(" ")
          @bridge_stp = config.stp ? "on" : "off"
          @bridge_forward_delay = config.forward_delay.to_s
        when ConnectionConfig::Bonding
          @bonding_module_opts = config.options
          config.slaves.each_with_index do |slave, index|
            public_send(:"bonding_slave#{index}=", slave)
          end
        when ConnectionConfig::Wireless
          init_from_wireless(config)
        end

        true
      end

      # Helper to get wireless keys as array
      # @return [Array<String>]
      def wireless_keys
        keys = []
        (0..3).each do |i|
          key = public_send(:"wireless_key#{i}")
          keys << key unless key.empty?
        end

        keys
      end

      # Helper to get bonding slaves as array
      # @return [Array<String>]
      def bonding_slaves
        slaves = []

        (0..9).each do |i|
          slave = public_send(:"bonding_slave#{i}")
          slaves << slave unless slave.empty?
        end

        slaves
      end

    private

      def init_from_wireless(config)
        @wireless_mode = config.mode
        @wireless_ap = config.ap
        @wireless_bitrate = config.bitrate.to_s
        @wireless_ca_cert = config.ca_cert
        @wireless_channel = config.channel.to_s if config.channel
        @wireless_client_cert = config.client_cert
        @wireless_client_key = config.client_key
        @wireless_essid = config.essid
        @wireless_auth_mode = config.auth_mode.to_s
        @wireless_nick = config.nick
        @wireless_nwid = config.nwid
        @wireless_wpa_anonid = config.wpa_anonymous_identity
        @wireless_wpa_identity = config.wpa_identity
        @wireless_wpa_password = config.wpa_password
        @wireless_wpa_psk = config.wpa_psk
        config.keys.each_with_index do |key, index|
          public_send(:"wireless_key#{index}=", key)
        end
        @wireless_key = config.default_key.to_s
        @wireless_key_length = config.key_length.to_s
        # power dropped
        # peap version not supported yet
        # on other hand ap scan mode is not in autoyast
      end
    end
  end
end
