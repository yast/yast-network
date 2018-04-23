require "y2remote/modes/base"
require "y2remote/modes/socket_based"

module Y2Remote
  module Modes
    class VNC < Base
      include SocketBased

      SOCKET = "xvnc".freeze

      def initialize
        super()
        Yast.import "Packages"
      end

      def required_packages
        Yast::Packages.vnc_packages
      end

      def socket_name
        SOCKET
      end

      def service_name
        "#{socket_name}@*"
      end
    end
  end
end
