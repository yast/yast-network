Yast.import "LanItems"
require "cwm/common_widgets"

module Y2Network
  module Widgets
    class BondOptions < CWM::ComboBox
      def initialize(settings)
        textdomain "network"
        @settings = settings
      end

      def items
        [
          ["mode=balance-rr miimon=100", "mode=balance-rr miimon=100"],
          ["mode=active-backup miimon=100", "mode=active-backup miimon=100"],
          ["mode=balance-xor miimon=100", "mode=balance-xor miimon=100"],
          ["mode=broadcast miimon=100", "mode=broadcast miimon=100"],
          ["mode=802.3ad miimon=100", "mode=802.3ad miimon=100"],
          ["mode=balance-tlb miimon=100", "mode=balance-tlb miimon=100"],
          ["mode=balance-alb miimon=100", "mode=balance-alb miimon=100"]
        ]
      end

      def help
        _(
          "<p>Select the bond driver options and edit them if necessary. </p>"
        )
      end

      def label
        _("&Bond Driver Options")
      end

      def opt
        [:hstretch, :editable]
      end

      def init
        @settings["BONDOPTION"] = Yast::LanItems.bond_option # TODO: not here
        self.value = @settings["BONDOPTION"]
      end

      def store
        @settings["BONDOPTION"] = value
        Yast::LanItems.bond_option = @settings["BONDOPTION"] # TODO: not here
      end
    end
  end
end
