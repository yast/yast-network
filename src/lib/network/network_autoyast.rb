require "yast"

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
      Yast.import "LanItems"
      Yast.import "Linuxrc"
      Yast.import "Host"
      Yast.import "AutoInstall"
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

    # Creates udev rules according definition from profile
    def create_udevs
      return if !Mode.autoinst

      log.info("Applying udev rules according to AY profile")

      # get implicitly defined udev rules (via old style names)
      im_udev_rules = LanItems.createUdevFromIfaceName(ay_networking_section["interfaces"])
      log.info("- implicitly defined udev rules: #{im_udev_rules}")

      no_rules = im_udev_rules.empty?

      # get explicit udev definition from the profile
      ex_udev_rules = ay_networking_section["net-udev"] || []
      log.info("- explicitly defined udev rules: #{ex_udev_rules}")

      no_rules &&= ex_udev_rules.empty?
      return if no_rules

      # for the purpose of setting the persistent names, create the devices 1st
      s390_devices = ay_networking_section.fetch("s390-devices", {})
      s390_devices.each { |rule| LanItems.createS390Device(rule) } if Arch.s390

      LanItems.Read

      # implicitly defined udev rules are overwritten by explicit ones in
      # case of collision.
      assign_udevs_to_devs(im_udev_rules)
      assign_udevs_to_devs(ex_udev_rules)

      LanItems.write
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
    # If the installer is running in 1st stage mode only, then the configuration
    # is also written
    #
    # @param [Boolean] write forces instant writing of the configuration
    # @return [Boolean] true when configuration was present and loaded from the profile
    def configure_lan(write: false)
      log.info("NetworkAutoYast: Lan configuration")

      ay_configuration = Lan.FromAY(ay_networking_section)
      ay_configuration = NetworkAutoYast.instance.merge_configs(ay_configuration) if keep_net_config?

      configure_submodule(Lan, ay_configuration, write: write)
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

    # Checks if the udev rule is valid for renaming a NIC
    def valid_rename_udev_rule?(rule)
      return false if rule["name"].nil? || rule["name"].empty?
      return false if rule["rule"].nil? || rule["rule"].empty?
      return false if rule["value"].nil? || rule["value"].empty?

      true
    end

    # Renames a network device represented by given item.
    #
    # @param item [Integer] is an item id. See LanItems for detail
    # @param name_to [String] new device name
    # @param attr [String] an udev attribute usable in NIC's rule. Currently just
    #  "KERNELS" or "ATTR{address}" makes sense. This parameter is optional
    # @param key [String] for the given udev attribute. Optional parameter.
    def rename_lan_item(item, name_to, attr = nil, key = nil)
      return if item.nil? || item < 0 || item >= LanItems.Items.size
      return if name_to.nil? || name_to.empty?

      # selecting according device name is unreliable (selects only in between configured devices)
      LanItems.current = item
      LanItems.InitItemUdevRule(item)

      if !attr.nil? && !key.nil?
        # find out what attribude is currently used for setting device name and
        # change it if needed. Currently mac is used by default. So, we check is it is
        # the other one (busid). If no we defaults to mac.
        bus_attr = LanItems.GetItemUdev("KERNELS")
        current_attr = bus_attr.empty? ? "ATTR{address}" : "KERNELS"

        # make sure that we base renaming on defined attribute with value given in AY profile
        LanItems.ReplaceItemUdev(current_attr, attr, key)
      elsif attr.nil? ^ key.nil? # xor
        raise ArgumentError, "Not enough data for udev rule definition"
      end

      LanItems.rename(name_to)

      nil
    end

    # Takes a list of udev rules and assignes them to corresponding devices.
    #
    # If a device has an udev rule defined already, it is overwritten by new one.
    # Note: initialization of LanItems has to be done outside of this method
    def assign_udevs_to_devs(udev_rules)
      return if udev_rules.nil?

      udev_rules.each do |rule|
        name_to = rule["name"]
        attr = rule["rule"]
        key = rule["value"]

        next if !valid_rename_udev_rule?(rule)
        key.downcase!

        # find item which matches to the given rule definition
        item_id, matching_item = LanItems.Items.find do |_, i|
          i["hwinfo"] &&
            (i["hwinfo"]["busid"].downcase == key || i["hwinfo"]["mac"].downcase == key)
        end
        next if !matching_item

        name_from = LanItems.current_name_for(item_id)
        log.info("Matching device found - renaming <#{name_from}> -> <#{name_to}>")

        # rename item in collision
        rename_lan_item(LanItems.colliding_item(name_to), name_from)

        # rename matching item
        rename_lan_item(item_id, name_to, attr, key)
      end
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

      write ||= !ay_general_section.fetch("mode", "second_stage" => true)["second_stage"]
      log.info("Write configuration instantly: #{write}")

      yast_module.Write(gui: false) if write

      true
    end
  end
end
