require "yast"
require "cwm/tabs"

# used widgets
require "y2network/widgets/bond_slave"
require "y2network/widgets/bond_options"

module Y2Network
  module Widgets
    class BondSlavesTab < CWM::Tab
      def initialize(settings)
        textdomain "network"

        @settings = settings
      end

      def label
        _("&Bond Slaves")
      end

      def contents
        VBox(BondSlave.new(@settings), BondOptions.new(@settings))
      end
    end
  end
end
