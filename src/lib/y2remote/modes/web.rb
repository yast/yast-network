require "y2remote/modes/base"

module Y2Remote
  class Modes
    class Web < Base
      SOCKET   = "xvnc-novnc".freeze
      PACKAGES = ["xorg-x11-Xvnc-novnc"].freeze

      def required_packages
        PACKAGES
      end

      def socket
        Yast::SystemdSocket.find(SOCKET)
      end

      def enabled?
        return false unless socket

        socket.enabled?
      end

      def enable!
        return false unless socket

        socket.enable!
      end

      def disable!
        return false unless socket

        socket.disable!
      end

      def stop!
        return false unless socket

        socket.stop!
      end

      def restart!
        return false unless socket

        stop!
        socket.start!
      end
    end
  end
end
