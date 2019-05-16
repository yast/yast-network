require "y2network/interface"
require "y2network/hardware_info"

module Y2Network
  # This class represents a physical interface (ethernet, wireless,
  # infiniband...)
  class PhysicalInterface < Interface
    # @return [Hwinfo]
    attr_accessor :hwinfo
  end
end
