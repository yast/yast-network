Yast.import "LanItems"
require "cwm/common_widgets"

module Y2Network
  module Widgets
    class BondOptions < CWM::ComboBox
      def initialize(settings)
        textdomain "network"
        @settings = settings
      end

      PRESET_ITEMS = [
        ["mode=balance-rr miimon=100", "mode=balance-rr miimon=100"],
        ["mode=active-backup miimon=100", "mode=active-backup miimon=100"],
        ["mode=balance-xor miimon=100", "mode=balance-xor miimon=100"],
        ["mode=broadcast miimon=100", "mode=broadcast miimon=100"],
        ["mode=802.3ad miimon=100", "mode=802.3ad miimon=100"],
        ["mode=balance-tlb miimon=100", "mode=balance-tlb miimon=100"],
        ["mode=balance-alb miimon=100", "mode=balance-alb miimon=100"]
      ].freeze

      def items
        PRESET_ITEMS
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
        self.value = @settings["BONDOPTION"]
      end

      def store
        @settings["BONDOPTION"] = value
      end
    end
  end
end
