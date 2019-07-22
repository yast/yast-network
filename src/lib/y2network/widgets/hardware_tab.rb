require "yast"
require "cwm/tabs"

# used widgets
require "y2network/widgets/blink_button"
require "y2network/widgets/kernel_module"
require "y2network/widgets/kernel_options"
require "y2network/widgets/ethtools_options"

module Y2Network
  module Widgets
    class HardwareTab < CWM::Tab
      def initialize(settings)
        textdomain "network"

        @settings = settings
      end

      def label
        _("&Hardware")
      end

      def contents
        VBox(
          # FIXME: ensure that only eth, maybe also ib?
          eth? ? BlinkButton.new(@settings) : Empty(),
          Frame(
            _("&Kernel Module"),
            HBox(
              HSpacing(0.5),
              VBox(
                VSpacing(0.4),
                HBox(
                  KernelModule.new(@settings),
                  HSpacing(0.5),
                  KernelOptions.new(@settings)
                ),
                VSpacing(0.4)
              ),
              HSpacing(0.5)
            )
          ),
          # FIXME: probably makes sense only for eth
          EthtoolsOptions.new(@settings),
          VStretch()
        )
      end

      def eth?
        @settings.type.ethernet?
      end
    end
  end
end
