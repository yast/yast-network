require "yast"
require "cwm/common_widgets"

Yast.import "Label"

module Y2Network
  module Widgets
    class KernelOptions < CWM::InputField
      def initialize(settings)
        textdomain "network"

        @settings = settings
      end

      def label
        Yast::Label.Options
      end

      def help
        _(
          "<p>Additionally, specify <b>Options</b> for the kernel module. Use this\n" \
            "format: <i>option</i>=<i>value</i>. Each entry should be space-separated, for example: <i>io=0x300 irq=5</i>. <b>Note:</b> If two cards are \n" \
            "configured with the same module name, the options will be merged while saving.</p>\n"
        )
      end

      def opt
        [:hstretch]
      end

      def init
        self.value = @settings.driver_options
      end

      def store
        @settings.driver_options = value
      end
    end
  end
end
