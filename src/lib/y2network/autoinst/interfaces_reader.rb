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
require "y2network/dns"
require "y2network/autoinst/type_detector"
require "installation/autoinst_issues"
require "ipaddr"

Yast.import "AutoInstall"

module Y2Network
  module Autoinst
    # This class is responsible of importing the AutoYast interfaces section
    class InterfacesReader
      include Yast::Logger
      include Yast::I18n

      # @return [AutoinstProfile::InterfacesSection]
      attr_reader :section

      # @param section [AutoinstProfile::InterfacesSection]
      def initialize(section)
        textdomain "network"

        @section = section
      end

      # Creates a new {ConnectionConfigsCollection} config from the imported profile interfaces
      # section
      # @note interfaces will be created automatic from connection configs
      #
      # @return [ConnectionConfigsCollection] the imported connections configs
      def config
        configs = @section.interfaces.map do |interface_section|
          log.info "Creating config for interface section: #{interface_section.inspect}"
          config = create_config(interface_section)
          config.propose # propose reasonable defaults for not set attributes

          unless load_generic(config, interface_section)
            log.info "Skipping interface as the configuration was wrongly defined"
            next
          end

          case config
          when ConnectionConfig::Vlan
            load_vlan(config, interface_section)
          when ConnectionConfig::Bridge
            load_bridge(config, interface_section)
          when ConnectionConfig::Bonding
            load_bonding(config, interface_section)
          when ConnectionConfig::Wireless
            load_wireless(config, interface_section)
          end

          log.info "Resulting config: #{config.inspect}"
          config
        end

        ConnectionConfigsCollection.new(configs.compact)
      end

    private

      def issues_list
        Yast::AutoInstall.issues_list
      end

      def name_from_section(interface_section)
        # device is just fallback
        return interface_section.device if interface_section.name.to_s.empty?

        interface_section.name
      end

      def add_invalid_issue(section, value, new_value)
        issues_list.add(::Installation::AutoinstIssues::InvalidValue,
          section, value, section.public_send(value),
          format(_("replaced by '%{value}'"), value: new_value))
      end

      def create_config(interface_section)
        name = name_from_section(interface_section)
        type = TypeDetector.type_of(name, interface_section)
        # TODO: TUN/TAP interface missing for autoyast?
        ConnectionConfig.const_get(type.class_name).new
      end

      def load_generic(config, interface_section)
        if !interface_section.bootproto.to_s.empty?
          bootproto = BootProtocol.from_name(interface_section.bootproto)
          if bootproto
            config.bootproto = bootproto
          else
            add_invalid_issue(interface_section, :bootproto, config.bootproto&.name)
          end
        else
          issues_list.add(::Installation::AutoinstIssues::MissingValue,
            interface_section, :bootproto)
        end

        config.name = name_from_section(interface_section)

        if config.name.empty?
          issues_list.add(::Installation::AutoinstIssues::MissingValue,
            interface_section, :name, _("The section will be skipped"))
          return
        end

        config.lladdress = interface_section.lladdr if !interface_section.lladdr.to_s.empty?
        config.interface = config.name # in autoyast name and interface is same
        description = interface_section.description.to_s
        config.description = interface_section.description if !description.empty?

        config.ip = load_ipaddr(interface_section)

        # handle aliases
        interface_section.aliases.each_with_index do |section, index|
          next if section.ipaddr.to_s.empty?

          config.ip_aliases << load_alias(section, id: "_#{index}")
        end

        # startmode
        if !interface_section.startmode.to_s.empty?
          startmode = Startmode.create(interface_section.startmode)
          if startmode
            config.startmode = startmode
          else
            add_invalid_issue(interface_section, :startmode, config.startmode&.name)
          end
        end

        if config.startmode&.name == "ifplugd" && !interface_section.ifplugd_priority.to_s.empty?
          config.startmode.priority = interface_section.ifplugd_priority
        end

        # mtu
        config.mtu = interface_section.mtu.to_i if !interface_section.mtu.to_s.empty?

        # ethtool options
        if interface_section.ethtool_options
          config.ethtool_options = interface_section.ethtool_options
        end

        # fw zone
        config.firewall_zone = interface_section.zone if !interface_section.zone.to_s.empty?

        # DHCLIENT_SETHOSTNAME setup
        if !interface_section.dhclient_set_hostname.empty?
          config.dhclient_set_hostname = interface_section.dhclient_set_hostname == "yes"
        end

        config
      end

      # Loads and intializates interface_section's ipaddr attribute
      #
      # @param section [Hash] hash of AY profile's interface section as obtained from parser
      #
      # @return [ConnectionConfig::IPConfig] created ipaddr object
      def load_ipaddr(section)
        return if section.ipaddr.empty?

        ipaddr = IPAddress.from_string(section.ipaddr)

        # Assign first netmask, as prefixlen has precedence so it will overwrite it
        ipaddr.prefix = prefix_for(section.netmask) if !section.netmask.to_s.empty?
        ipaddr.prefix = prefix_for(section.prefixlen) if !section.prefixlen.to_s.empty?

        broadcast = IPAddress.new(section.broadcast) if !section.broadcast.empty?
        remote = IPAddress.new(section.remote_ipaddr) if !section.remote_ipaddr.empty?

        ConnectionConfig::IPConfig.new(ipaddr, broadcast: broadcast, remote_address: remote)
      end

      # Converts a given IP Address netmask or prefix length in different
      # formats to its prefix length value.
      #
      # @param value [String] IP Address prefix length or netmask in its different formats
      # @return [Integer,nil] the given value in IP Address prefix length
      #   format
      def prefix_for(value)
        if value.empty?
          nil
        elsif value.start_with?("/")
          value[1..-1].to_i
        elsif value =~ /^\d{1,3}$/
          value.to_i
        else
          IPAddr.new("#{value}/#{value}").prefix
        end
      end

      # Loads and initializates an IP alias according to given hash with alias details
      #
      # @param section[AliasSection] hash of AY profile's alias section as obtained from parser
      #
      # @return [ConnectionConfig::IPConfig] alias details
      def load_alias(section, id: nil)
        ipaddr = IPAddress.from_string(section.ipaddr)
        # Assign first netmask, as prefixlen has precedence so it will overwrite it
        ipaddr.prefix = prefix_for(section.netmask) unless section.netmask.to_s.empty?
        ipaddr.prefix = prefix_for(section.prefixlen) unless section.prefixlen.to_s.empty?

        ConnectionConfig::IPConfig.new(ipaddr, id: id, label: section.label)
      end

      def load_wireless(config, interface_section)
        if !interface_section.wireless_mode.to_s.empty?
          config.mode = interface_section.wireless_mode
        end
        config.ap = interface_section.wireless_ap if !interface_section.wireless_ap.to_s.empty?
        if !interface_section.wireless_bitrate.to_s.empty?
          config.bitrate = interface_section.wireless_bitrate.to_f
        end
        config.ca_cert = interface_section.wireless_ca_cert if interface_section.wireless_ca_cert
        if !interface_section.wireless_channel.to_s.empty?
          config.channel = interface_section.wireless_channel.to_i
        end
        if !interface_section.wireless_client_cert.to_s.empty?
          config.client_cert = interface_section.wireless_client_cert
        end
        if !interface_section.wireless_client_key.to_s.empty?
          config.client_key = interface_section.wireless_client_key
        end
        config.essid = interface_section.wireless_essid if interface_section.wireless_essid
        if interface_section.wireless_auth_mode
          config.auth_mode = interface_section.wireless_auth_mode.to_sym
        end
        if !interface_section.wireless_nick.to_s.empty?
          config.nick = interface_section.wireless_nick
        end
        if !interface_section.wireless_nwid.to_s.empty?
          config.nwid = interface_section.wireless_nwid
        end

        if !interface_section.wireless_wpa_anonid.to_s.empty?
          config.wpa_anonymous_identity = interface_section.wireless_wpa_anonid
        end
        if !interface_section.wireless_wpa_identity.to_s.empty?
          config.wpa_identity = interface_section.wireless_wpa_identity
        end
        if !interface_section.wireless_wpa_password.to_s.empty?
          config.wpa_password = interface_section.wireless_wpa_password
        end
        if !interface_section.wireless_wpa_psk.to_s.empty?
          config.wpa_psk = interface_section.wireless_wpa_psk
        end
        config.keys = []
        (0..3).each do |i|
          key = interface_section.public_send(:"wireless_key#{i}")
          config.keys << key if key && !key.empty?
        end
        if !interface_section.wireless_key.to_s.empty?
          config.default_key = interface_section.wireless_key.to_i
        end
        if !interface_section.wireless_key_length.to_s.empty?
          config.key_length = interface_section.wireless_key_length.to_i
        end

        nil
      end

      def load_vlan(config, interface_section)
        config.vlan_id = interface_section.vlan_id.to_i if !interface_section.vlan_id.to_s.empty?
        config.parent_device = interface_section.etherdevice
      end

      def load_bridge(config, interface_section)
        config.ports = interface_section.bridge_ports.split
        if !interface_section.bridge_stp.to_s.empty?
          config.stp = interface_section.bridge_stp == "on"
        end
        if !interface_section.bridge_forward_delay.to_s.empty?
          config.forward_delay = interface_section.bridge_forward_delay.to_i
        end

        nil
      end

      def load_bonding(config, interface_section)
        if !interface_section.bonding_module_opts.empty?
          config.options = interface_section.bonding_module_opts
        end
        config.slaves = []
        (0..9).each do |i|
          slave = interface_section.public_send(:"bonding_slave#{i}")
          config.slaves << slave if slave && !slave.empty?
        end
      end
    end
  end
end
