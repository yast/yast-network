require "y2remote/modes/base"
require "y2remote/modes/sockets_mixin"

module Y2Remote
  module Modes
    class VNC < Base
      include SocketsMixin

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
    end
  end
end
