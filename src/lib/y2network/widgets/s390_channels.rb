require "cwm/custom_widget"
require "cwm/common_widgets"

module Y2Network
  module Widgets
    class S390Channels < CWM::CustomWidget
      def initialize(settings)
        textdomain "network"
        @settings = settings
      end

      def label
        ""
      end

      def contents
        HBox(
          S390ReadChannel.new(@settings),
          HSpacing(1),
          S390WriteChannel.new(@settings),
          HSpacing(1),
          S390DataChannel.new(@settings)
        )
      end
    end

    class S390ReadChannel < CWM::InputField
      def initialize(settings)
        textdomain "network"
        @settings = settings
      end

      def init
        self.value = @settings.read_channel
      end

      def opt
        [:hstretch]
      end

      def label
        _("&Read Channel")
      end

      def store
        @settings.read_channel = value
      end
    end

    class S390WriteChannel < CWM::InputField
      def initialize(settings)
        textdomain "network"
        @settings = settings
      end

      def init
        self.value = @settings.write_channel
      end

      def opt
        [:hstretch]
      end

      def label
        _("&Read Channel")
      end

      def store
        @settings.write_channel = value
      end
    end

    class S390DataChannel < CWM::InputField
      def initialize(settings)
        textdomain "network"
        @settings = settings
      end

      def init
        self.value = @settings.data_channel
      end

      def opt
        [:hstretch]
      end

      def label
        _("Control Channel")
      end

      def store
        @settings.data_channel = value
      end
    end
  end
end
