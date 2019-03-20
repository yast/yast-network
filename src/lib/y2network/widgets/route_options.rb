Yast.import "Netmask"
Yast.import "Label"

require "cwm/common_widgets"

module Y2Network
  module Widgets
    class RouteOptions < CWM::InputField
     # @param route route object to get and store netmask value
     # TODO: I expect it will be useful on multiple places, so we need find way how to store it
      def initialize(route)
        textdomain "network"
      end

      def label
        Yast::LAbel.Options
      end

      def help
        # TODO: original also does not have help
        ""
      end

      def opt
        [:hstretch]
      end

      def init
        # TODO: init from route object
      end
    end
  end
end
