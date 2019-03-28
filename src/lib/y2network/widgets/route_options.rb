Yast.import "Netmask"
Yast.import "Label"

require "cwm/common_widgets"

module Y2Network
  module Widgets
    class RouteOptions < CWM::InputField
      # @param route route object to get and store options
      def initialize(route)
        textdomain "network"

        @route = route
      end

      def label
        Yast::Label.Options
      end

      def help
        _(
          "<p><b>Options</b> specifies additional options for route. It is directly passed " \
            "to <i>ip route add</i> with exception of <i>to</i>,<i>via</i> and <i>dev</i>."
        )
      end

      def opt
        [:hstretch]
      end

      def init
        self.value = @route.options
      end

      def store
        @route.options = value
      end
    end
  end
end
