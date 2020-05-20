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
      dns = from_system["dns"] || {}
      routing = from_system["routing"] || {}
      devices = from_system["devices"] || {}

      return from_system if conf.nil? || conf.empty?

      # copy the keys/values that are not existing in the XML
      # so we merge the inst-sys settings with the XML while XML
      # has higher priority
      conf["dns"] = merge_dns(dns, conf["dns"])
      conf["routing"] = merge_routing(routing, conf["routing"])
      # merge devices definitions obtained from inst-sys
      # and those which were read from AY profile. bnc#874259
      conf["devices"] = merge_devices(devices, conf["devices"])

      conf
    end

    # Sets network service for target
    def set_network_service
      return if !Mode.autoinst

      log.info("Setting network service according to AY profile")

      use_network_manager = ay_networking_section["managed"]
      use_network_manager = Lan.UseNetworkManager if use_network_manager.nil?

      nm_available = NetworkService.is_backend_available(:network_manager) if use_network_manager

      if use_network_manager && nm_available
        log.info("- using NetworkManager")

        NetworkService.use_network_manager
      else
        log.info("- using wicked")
        log.warn("- NetworkManager requested but not available") if use_network_manager

        NetworkService.use_wicked
      end

      NetworkService.EnableDisableNow
    end

    # Initializates NICs setup according AY profile
    #
    # If the network was already written before the proposal or the second
    # stage is not omitted, then, it returns without touching the config.
    #
    # @param [Boolean] write forces instant writing of the configuration
    # @return [Boolean] true when configuration was present and loaded from the profile
    def configure_lan(write: false)
      log.info("NetworkAutoYast: Lan configuration")
      return false if !write && (Lan.autoinst.before_proposal || second_stage?)

      ay_configuration = Lan.FromAY(ay_networking_section)
      if keep_net_config?
        ay_configuration = NetworkAutoYast.instance.merge_configs(ay_configuration)
      end

      configure_submodule(Lan, ay_configuration, write: write)
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
    #
    # @param [Boolean] write forces instant writing of the configuration
    # @return [Boolean] true when configuration was present and loaded from the profile
    def configure_hosts(write: false)
      log.info("NetworkAutoYast: Hosts configuration")

      hosts_config = (ay_host_section["hosts"] || {}).map do |host|
        # we need to guarantee order of the items here
        [host["host_address"] || "", host["names"] || []]
      end
      hosts_config = hosts_config.to_h.delete_if { |k, v| k.empty? || v.empty? }

      configure_submodule(Host, "hosts" => hosts_config, write: write)
    end

    # Checks if the profile asks for keeping installation network configuration
    def keep_net_config?
      ret = ay_networking_section.fetch("keep_install_network", true)

      log.info("NetworkAutoYast: keep installation network: #{ret}")

      ret
    end

  private

    # Merges two devices map into one.
    #
    # Maps are expected in NetworkInterfaces format. That is
    # {
    #   type1:
    #   {
    #     dev_name_1: { ... },
    #     ...
    #   },
    #   ...
    # }
    #
    # If a device definition is present in both maps, then the one from devices2
    # wins.
    #
    # @param [Hash, nil] in_devs1 first map of devices in NetworkInterfaces format
    # @param [Hash, nil] in_devs2 second map of devices in NetworkInterfaces format
    #
    # @return merged device map in NetworkInterfaces format or empty map
    def merge_devices(in_devs1, in_devs2)
      return in_devs2 if in_devs1.nil? && !in_devs2.nil?
      return in_devs1 if in_devs2.nil? && !in_devs1.nil?
      return {} if in_devs1.nil? && in_devs2.nil?

      in_devs1.merge(in_devs2) do |_key, devs1_vals, devs2_vals|
        devs1_vals.merge(devs2_vals)
      end
    end

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

    # Returns current AY profile in the internal representation
    #
    # @return [Hash] hash representing current profile or empty hash
    def ay_current_profile
      Yast.import "Profile"

      ay_profile = Profile.current

      return {} if ay_profile.nil? || ay_profile.empty?

      ay_profile
    end

    # Returns networking section of current AY profile
    def ay_networking_section
      return {} if ay_current_profile["networking"].nil?

      ay_current_profile["networking"]
    end

    # Returns global section of current AY profile
    def ay_general_section
      return {} if ay_current_profile["general"].nil?

      ay_current_profile["general"]
    end

    # Returns host section of the current AY profile
    #
    # Note that autoyast transforms the host's subsection
    # into:
    # {
    #   hosts => [
    #     # first <host_entry>
    #     {
    #       "host_address" => <ip>,
    #       "names" => [list, of, names]
    #     }
    #     # second <host_entry>
    #     ...
    #   ]
    # }
    #
    # return <Hash> with hosts configuration
    def ay_host_section
      return {} if ay_current_profile["host"].nil?

      ay_current_profile["host"]
    end

    # Configures given yast submodule according AY configuration
    #
    # It takes data from AY profile transformed into a format expected by the YaST
    # sub module's Import method.
    #
    # It imports the profile, configures the module and writes the configuration.
    # Writing the configuration is optional when second stage is available and mandatory
    # when running autoyast installation with first stage only.
    def configure_submodule(yast_module, ay_config, write: false)
      return false if !ay_config

      yast_module.Import(ay_config)

      # Results of imported values semantic check.
      # Return true in order to not call the NetworkAutoconfiguration.configure_hosts
      return true unless AutoInstall.valid_imported_values

      log.info("Write configuration instantly: #{write}")
      yast_module.Write(gui: false) if !second_stage? || write

      true
    end

    # Convenience method to check whether the second stage is enabled or not
    #
    # @return[Boolean]
    def second_stage?
      ay_general_section.fetch("mode", {}).fetch("second_stage", true)
    end
  end
end
