require "y2remote/modes/base"
require "y2remote/modes/sockets_mixin"

module Y2Remote
  module Modes
    class Web < Base
      include SocketsMixin

      SOCKET   = "xvnc-novnc".freeze
      PACKAGES = ["xorg-x11-Xvnc-novnc"].freeze

      def required_packages
        PACKAGES
      end

      def socket_name
        SOCKET
      end
    end
  end
end
