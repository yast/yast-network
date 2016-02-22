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

    Yast.import "Lan"
    Yast.import "LanItems"
    Yast.import "Linuxrc"

    # Merges existing config from system into given configuration map
    #
    # @param [Hash, nil] configuration map
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
    #
    # FIXME: Currently used only for applying udev rules during network
    # installations (ssh, vnc, ...). It was introduced as a quick fix for
    # bnc#944349, so it is currently limited only on {ssh|vnc} installations.
    #
    # @param AY profile, @see e.g. Profile.current
    def create_udevs(ay_profile)
      return if !(Linuxrc.usessh || Linuxrc.vnc)

      log.info("Applying udev rules according AY profile")

      udev_rules = ay_profile["networking"]["net-udev"]
      log.info("- udev rules: #{udev_rules}")

      return if udev_rules.nil? || udev_rules.empty?

      LanItems.Read

      udev_rules.each do |rule|
        name_to = rule["name"]
        attr = rule["rule"]
        key = rule["value"].downcase
        item, matching_item = LanItems.Items.find { |_, i| i["hwinfo"]["busid"].downcase == key || i["hwinfo"]["mac"].downcase == key }
        next if !matching_item

        # for logging only
        name_from = matching_item["ifcfg"] || matching_item["dev_name"]
        log.info("- renaming <#{name_from}> -> <#{name_to}>")

        # selecting according device name is unreliable (selects only in between configured devices)
        LanItems.current = item

        # find out what attribude is currently used for setting device name and
        # change it if needed. Currently mac is used by default. So, we check is it is
        # the other one (busid). If no we defaults to mac.
        bus_attr = LanItems.GetItemUdev("KERNELS")
        current_attr = bus_attr.empty? ? "ATTR{address}" : "KERNELS"

        # make sure that we base renaming on defined attribute with value given in AY profile
        LanItems.ReplaceItemUdev(current_attr, attr, key)
        LanItems.rename(name_to)
      end

      LanItems.write
    end

    # Sets network service for target
    def set_network_service(ay_profile)
      log.info("Setting network service according AY profile")

      use_network_manager = ay_profile["networking"]["managed"]
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
  end
end
