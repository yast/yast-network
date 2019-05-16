require "y2network/interface"
require "y2network/hardware_info"

module Y2Network
  class PhysicalInterface < Interface
    # @return [HardwareInfo]
    attr_accessor :hwinfo
  end
end
