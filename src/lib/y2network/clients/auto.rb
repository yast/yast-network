# Copyright (c) [2020] SUSE LLC
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
require "installation/auto_client"

Yast.import "Lan"
Yast.import "Progress"

module Y2Network
  module Clients
    # This class is responsible of AutoYaST network configuration
    class Auto < ::Installation::AutoClient
      # Constructor
      def initialize
        super
        textdomain "network"

        Yast.include self, "network/lan/wizards.rb"
      end

      def read
        @progress_orig = Yast::Progress.set(false)
        ret = Yast::Lan.Read(:nocache)
        Yast::Progress.set(@progress_orig)
        ret
      end

      def write
        @progress_orig = Yast::Progress.set(false)

        result = Yast::Lan.WriteOnly
        log.error("Writing lan config failed") if !result
        @ret &&= result
        timeout = Yast::Lan.autoinst.ip_check_timeout || -1

        if (timeout >= 0) && Lan.isAnyInterfaceDown
          Builtins.y2debug("timeout %1", timeout)
          error_text = _("Configuration Error: uninitialized interface.")
          (timeout == 0) ? Popup.Error(error_text) : Popup.TimedError(error_text, timeout)
        end

        Yast::Progress.set(@progress_orig)
      end

      def summary
        Yast::Lan.Summary("summary")
      end

      def reset
        Yast::Lan.Import({})
        Yast::Lan.clear_configs
        {}
      end

      def change
        if !Yast::Lan.yast_config
          Yast::Lan.add_config(:yast, Y2Network::Config.new(:source, :config))
        end
        LanAutoSequence("")
      end

      def import(profile)
        Yast::NetworkAutoYast.instance.ay_networking_section = profile

        modified_profile = Yast::Lan.FromAY(profile)

        # see bnc#498993
        # in case keep_install_network is set to true (in AY)
        # we'll keep values from installation
        # and merge with XML data (bnc#712864)
        if modified_profile.fetch("keep_install_network", true)
          modified_profile = Yast::NetworkAutoYast.instance.merge_configs(modified_profile)
        end

        Yast::Lan.Import(modified_profile)

        true
      end

      def packages
        Yast::Lan.AutoPackages
      end

      def modified
        self.class.modified = true
      end

      def modified?
        !!self.class.modified
      end

      class << self
        attr_accessor :modified
      end

      def export
        raw_config = Yast::Lan.Export
        log.debug("settings: #{raw_config.inspect}")
        adapt_for_autoyast(raw_config)
      end

    private

      def merge_current_config?
        !!Yast::Lan.autoinst.keep_install_network
      end

      # Convert data from native network to autoyast for XML
      #
      # @todo we should get rid of this method moving the logic to the
      # Y2Network::AutoinstProfile::NetworkingSection in case we cannot remove
      # it completely
      #
      # @param [Hash] settings native network settings
      # @return [Hash] autoyast network settings
      def adapt_for_autoyast(settings)
        settings = deep_copy(settings)
        interfaces = settings["interfaces"] || []
        log.info("interfaces: #{interfaces.inspect}")
        net_udev = settings["net-udev"] || []
        log.info("net-udev: #{net_udev.inspect}")

        # Modules
        s390_devices = settings["s390-devices"] || []
        log.info("s390-devices: #{s390_devices.inspect}")

        modules = []
        settings.fetch("hwcfg", {}).each do |device, mod|
          newmap = { "device" => device }
          newmap["module"] = mod.fetch("MODULE", "")
          newmap["options"] = mod.fetch("MODULE_OPTIONS", "")
          modules << newmap
        end

        config = settings.fetch("config", {})
        dhcp = config.fetch("dhcp", {})
        dhcp_hostname = dhcp.fetch("DHCLIENT_SET_HOSTNAME", false)
        dns = settings.fetch("dns", {})
        dns["dhcp_hostname"] = dhcp_hostname
        dhcpopts = {}
        if dhcp.keys.include?("DHCLIENT_HOSTNAME_OPTION")
          dhcpopts["dhclient_hostname_option"] = dhcp.fetch("DHCLIENT_HOSTNAME_OPTION", "AUTO")
        end
        if dhcp.keys.include?("DHCLIENT_ADDITIONAL_OPTIONS")
          dhcpopts["dhclient_additional_options"] = dhcp.fetch("DHCLIENT_ADDITIONAL_OPTIONS", "")
        end
        if dhcp.keys.include?("DHCLIENT_CLIENT_ID")
          dhcpopts["dhclient_client_id"] = dhcp.fetch("DHCLIENT_CLIENT_ID", "")
        end

        ret = { "managed" => settings.fetch("managed", false) }
        ret["ipv6"] = settings.fetch("ipv6", true) if settings.keys.include?("ipv6")
        ret["keep_install_network"] = settings.fetch("keep_install_network", true)
        ret["modules"] = modules unless modules.empty?
        ret["dns"] = dns unless dns.empty?
        ret["dhcp_options"] = dhcpopts unless dhcpopts.empty?
        ret["routing"] = settings["routing"] unless settings.fetch("routing", {}).empty?
        ret["interfaces"] = interfaces unless interfaces.empty?
        ret["s390-devices"] = s390_devices unless s390_devices.empty?
        ret["net-udev"] = net_udev unless net_udev.empty?
        ret.dup
      end
    end
  end
end
