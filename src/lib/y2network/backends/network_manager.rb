require "y2network/backend"

module Y2Network
  module Backends
    # This class represents the NetworkManager backend
    class NetworkManager < Backend
      def initialize
        super(:network_manager)
      end

      def label
        _("Network Manager")
      end
    end
  end
end
