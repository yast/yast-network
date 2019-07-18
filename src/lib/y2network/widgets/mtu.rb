require "cwm/common_widgets"

module Y2Network
  module Widgets
    class MTU < CWM::ComboBox
      def initialize(settings)
        textdomain "network"
        @settings = settings
      end

      def label
        _("Set &MTU")
      end

      def opt
        [:hstretch, :editable]
      end

      def default_items
        [
          # translators: MTU value description (size in bytes, desc)
          ["1500", _("1500 (Ethernet, DSL broadband)")],
          ["1492", _("1492 (PPPoE broadband)")],
          ["576", _("576 (dial-up)")]
        ]
      end

      def ipoib_items
        [
          # translators: MTU value description (size in bytes, desc)
          ["65520", _("65520 (IPoIB in connected mode)")],
          ["2044", _("2044 (IPoIB in datagram mode)")]
        ]
      end

      def items
        @settings["IFCFGTYPE"] == "ib" ? ipoib_items : default_items
      end

      def init
        change_items(items)
        self.value = @settings["MTU"]
      end

      def store
        @settings["MTU"] = value
      end
    end
  end
end
