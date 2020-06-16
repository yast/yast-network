require "y2network/backend"

module Y2Network
  module Backends
    # This class represents the wicked backend
    class Wicked < Backend
      def initialize
        super(:wicked)
      end

      def label
        _("Wicked Service")
      end
    end
  end
end
