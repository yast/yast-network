require "y2network/interface"

module Y2Network
  module Interfaces
    class Physical < Interface
      # @return [HardwareInfo]
      attr_accessor :hwinfo
    end
  end
end
