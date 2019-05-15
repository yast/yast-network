require "y2network/connection/connection"

module Y2Network
  module Connection
    # This class represents a bonding connection
    #
    # @see https://www.kernel.org/doc/Documentation/networking/bonding.txt
    class Bond < Config
      # @return [Array<Interface>]
      attr_accessor :slaves
      # @return [String] bond driver options
      attr_accessor :options

      def initialize
        @slaves = []
        @options = ""
      end
    end
  end
end
