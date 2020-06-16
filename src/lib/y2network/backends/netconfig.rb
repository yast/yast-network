require "y2network/backend"

module Y2Network
  module Backends
    # This class represents the Netconfig backend
    class Netconfig < Backend
      def initialize
        super(:netconfig)
      end

      def label
        _("Traditional ifup")
      end
    end
  end
end
