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
        # TODO: original also does not have help
        ""
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
