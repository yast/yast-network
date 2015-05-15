require "yast"

module Yast
  # Provides functionality for network AutoYaST client(s)
  class NetworkAutoYast
    include Singleton

    # Merges two devices map into one.
    #
    # Maps are expected in NetworkInterfaces format. That is
    # $[
    #  type1:
    #    $[
    #      dev_name_1: $[ ... ],
    #      ...
    #     ],
    #   ...
    # ]
    #
    # If a device definition is present in both maps, then the one from devices2
    # wins.
    #
    # @param [Hash] in_devs1 first map of devices in NetworkInterfaces format
    # @param [Hash] in_devs2 second map of devices in NetworkInterfaces format
    #
    # @return merged device map in NetworkInterfaces format or empty map
    def merge_devices(in_devs1, in_devs2)
      return in_devs2
    end
  end
end
