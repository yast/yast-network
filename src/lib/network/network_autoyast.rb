require "yast"

module Yast
  # Provides functionality for network AutoYaST client(s)
  class NetworkAutoYast
    include Singleton

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
    # Value in first map has precendence over the value in second one in
    # case of key collision.
    #
    # bnc#796580 The problem with this is that due to compatibility with
    # older profiles, a missing element may have a different meaning than
    # "use what the filesystem/kernel currently uses".
    # In particular, a missing write_hostname means
    # "use the product default from DVD1/control.xml".
    # Other elements may have similar problems,
    # to be fixed post-PTF for maintenance.
    def merge_dns(in_dns1, in_dns2)
      ret = in_dns1

      Builtins.foreach(in_dns2) do |key, value|
        if !Builtins.haskey(in_dns1, key) && key != "write_hostname"
          Builtins.y2milestone(
            "(dns) taking %1 from inst-sys. Value = %2",
            key,
            value
          )
          ret[key] = value
        end
      end

      ret
    end
  end
end
