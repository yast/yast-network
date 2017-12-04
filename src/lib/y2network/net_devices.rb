module Y2Network
  require "yast" # for logger

  # A container class for network devices
  class NetDevices
    include Yast::Logger
    include Enumerable

    # Appends the device object into the container
    #
    # For object definition see @NetDevice
    def push(device)
      # TODO: check if device is desired object type
      cache[device.name] = device
    end

    # Clears stored data
    def reset
      log.info("NetDevices: clearing the cache")
    end
  end
end
