require "y2network/dialogs/popup"
require "y2network/widgets/wireless_networks"

module Y2Network
  module Dialogs
    class WirelessNetworks < Popup
      def initialize(networks)
        textdomain "network"

        @networks = networks
      end

      def title
        _("Wireless Available Networks")
      end

      def contents
        networks_table
      end

    protected

      def min_width
        60
      end

    private

      def networks_table
        @networks_table ||= Y2Network::Widgets::WirelessNetworks.new(@networks)
      end
    end
  end
end
