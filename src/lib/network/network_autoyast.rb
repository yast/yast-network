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
      Yast.import "Lan"
      Yast.import "LanItems"
      Yast.import "Linuxrc"
    end

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

    # Returns networking section of current AY profile
    def ay_networking_section
      Yast.import "Profile"

      ay_profile = Profile.current

      return {} if ay_profile.nil? || ay_profile.empty?
      return {} if ay_profile["networking"].nil?

      ay_profile["networking"]
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
        key = rule["value"].downcase
        item, matching_item = LanItems.Items.find do |_, i|
          i["hwinfo"]["busid"].downcase == key || i["hwinfo"]["mac"].downcase == key
        end
        next if !matching_item

        # for logging only
        name_from = matching_item["ifcfg"] || matching_item["dev_name"]
        log.info("Matching device found - renaming <#{name_from}> -> <#{name_to}>")

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
    end
  end
end
