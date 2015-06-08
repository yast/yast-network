require "yast"

module Yast
  # Provides functionality for network AutoYaST client(s)
  class NetworkAutoYast
    include Singleton

    # Merges existing config from system into given configuration map
    #
    # @param [Hash, nil] configurtion map
    #
    # @return updated configuration map
    def merge_configs(conf)
      Yast.import "Lan"

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

      return in_devs1.merge(in_devs2) do |key, devs1_vals, devs2_vals|
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

      instsys_dns.delete_if { |k,v| k == "write_hostname" }.merge(ay_dns)
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
