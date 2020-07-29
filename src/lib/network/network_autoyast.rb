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
require "y2network/autoinst_profile/s390_devices_section"
require "y2network/autoinst/s390_devices_reader"
require "y2network/interface_config_builder"
require "y2network/s390_device_activator"

module Yast
  # Provides functionality for network AutoYaST client(s)
  #
  # This currently shouldn't replace *::Import methods. In other
  # words it is intended for functionality which cannot be handled
  # in 2nd stage properly. Typically:
  #   - merging configuration provided by linuxrc means and AY profile
  #     together
  #   - target network service setup (to avoid need of restarting the
  #     service during 2nd stage) and all other stuff which could lead
  #     to the need of restarting the service (e.g. device renaming)
  class NetworkAutoYast
    include Singleton
    include Logger

    def initialize
      # import has to be done here, there are some collisions otherwise
      Yast.import "Arch"
      Yast.import "Lan"
      Yast.import "Linuxrc"
      Yast.import "Host"
      Yast.import "AutoInstall"
      Yast.import "Stage"
    end

    # Merges existing config from system into given configuration map
    #
    # @param conf [Hash, nil] configuration map
    #
    # @return updated configuration map
    def merge_configs(conf)
      # read settings from installation
      Lan.Read(:cache)
      # export settings into AY map
      from_system = Lan.Export
      return from_system if conf.nil? || conf.empty?

      dns = from_system["dns"] || {}
      routing = from_system["routing"] || {}

      # copy the keys/values that are not existing in the XML
      # so we merge the inst-sys settings with the XML while XML
      # has higher priority
      conf["dns"] = merge_dns(dns, conf["dns"])
      conf["routing"] = merge_routing(routing, conf["routing"])

      conf
    end

    # Sets network service for target
    def set_network_service
      return if !Mode.autoinst

      log.info("Setting network service according to AY profile")

      use_network_manager = Lan.yast_config&.backend?(:network_manager)

      if use_network_manager && Lan.yast_config.backend.available?
        log.info("- using NetworkManager")
      else
        log.info("- using wicked")
        log.warn("- NetworkManager requested but not available") if use_network_manager
        Lan.yast_config&.backend = :wicked
      end

      NetworkService.use(Lan.yast_config&.backend&.id)
      NetworkService.EnableDisableNow
    end

    # Writes the autoyast network configuration according to the already
    # imported configuration
    #
    # If the network was already written before the proposal it returns without
    # touching it
    #
    # @return [Boolean] true when written
    def configure_lan
      log.info("NetworkAutoYast: Lan configuration")
      return false if Lan.autoinst.before_proposal

      # force a write only as it is run at the end of the installation and it
      # is already chrooted in the target system where restarting services or
      # refreshing udev rules does not make sense at all
      Lan.Write(apply_config: false)
    end

    # Takes care of activate s390 devices from the profile declaration
    def activate_s390_devices(section = nil)
      profile_devices = section || ay_networking_section["s390-devices"] || {}
      devices_section = Y2Network::AutoinstProfile::S390DevicesSection
        .new_from_hashes(profile_devices)
      connections = Y2Network::Autoinst::S390DevicesReader.new(devices_section).config

      connections.each do |conn|
        builder = Y2Network::InterfaceConfigBuilder.for(conn.type, config: conn)
        activator = Y2Network::S390DeviceActivator.for(builder)
        if !activator.configured_interface.empty?
          log.info "Interface #{activator.configured_interface} is already active. " \
            "Skipping the activation."
          next
        end

        log.info "Created interface #{activator.configured_interface}" if activator.configure
      rescue RuntimeError => e
        log.error("An error ocurred when trying to activate the s390 device: #{conn.inspect}")
        log.error("Error: #{e.inspect}")
      end

      true
    end

    # Initializates /etc/hosts according AY profile
    #
    # If the installer is running in 1st stage mode only, then the configuration
    # is also written
    def configure_hosts
      Host.Write(gui: false)
    end

    # Checks if the profile asks for keeping installation network configuration
    def keep_net_config?
      ret = Lan.autoinst.keep_install_network

      log.info("NetworkAutoYast: keep installation network: #{ret}")

      ret
    end

    # setter for networking section. Should be done during import.
    # @return [Hash] networking section hash
    attr_writer :ay_networking_section

  private

    # Merges two maps with dns related values.
    #
    # Value in second map has precendence over the value in first one in
    # case of key collision.
    #
    # bnc#796580 The problem with this is that due to compatibility with
    # older profiles, a missing element may have a different meaning than
    # "use what the filesystem/kernel currently uses".
    # In particular, a missing write_hostname means
    # "use the product default from DVD1/control.xml".
    # Other elements may have similar problems,
    # to be fixed post-PTF for maintenance.
    #
    # @param instsys_dns [Hash, nil] first map with DNS configuration
    # @param ay_dns [Hash, nil] second map with DNS configuration
    #
    # @return merged DNS maps or empty map
    def merge_dns(instsys_dns, ay_dns)
      ay_dns ||= {}
      instsys_dns ||= {}

      instsys_dns.delete_if { |k, _v| k == "write_hostname" }.merge(ay_dns)
    end

    # Merges two maps with routing related values
    #
    # Value in second map has precendence over the value in first one in
    # case of key collision.
    #
    # @param instsys_routing [Hash, nil] first map with routing configuration
    # @param ay_routing [Hash, nil] second map with routing configuration
    #
    # @return merged DNS maps or empty map
    def merge_routing(instsys_routing, ay_routing)
      ay_routing ||= {}
      instsys_routing ||= {}

      instsys_routing.merge(ay_routing)
    end

    # Returns networking section of current AY profile
    def ay_networking_section
      @ay_networking_section || {}
    end
  end
end
