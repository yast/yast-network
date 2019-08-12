require "cwm/common_widgets"

module Y2Network
  module Widgets
    class WirelessChannel < CWM::ComboBox
      def initialize(settings)
        @settings = settings

        textdomain "network"
      end

      def init
        disable
      end

      def label
      _("&Channel")
      end

      def opt
        [:hstretch]
      end

      def items
        1.upto(14).map { |c| [c.to_s, c.to_s] }.prepend(["", _("Automatic")])
      end
    end

    class WirelessBitRate < CWM::ComboBox
      def initialize(settings)
        @settings = settings

        textdomain "network"
      end

      def opt
        [:hstretch]
      end

      def label
        _("B&it Rate")
      end

      def items
        bitrates.map { |b| [b.to_s, b.to_s] }.prepend(["", _("Automatic")])
      end

    private

      def bitrates
        [54,48,36,24,18,12,11,9,6,5.5,2,1]
      end
    end

    class WirelessAccessPoint< CWM::InputField
      def initialize(settings)
        @settings = settings
      end

      def opt
        [:hstretch]
      end

      def label
        _("&Access Point")
      end

      def init
        self.value = @settings.access_point
      end
    end

    class WirelessPowerManagement < CWM::CheckBox
      def initialize(settings)
        @settings = settings
      end

      def label
        _("Use &Power Management")
      end

      def init
        self.value = true
      end
    end

    class WirelessAPScanMode < CWM::IntField
      def initialize(settings)
        @settings = settings
      end

      def opt
        [:hstretch]
      end

      def label
        _("AP ScanMode")
      end

      def minimum
        0
      end

      def maximum
        2
      end
    end
  end
end
