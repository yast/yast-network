require 'yast'

module Y2Remote
  module Modes
    module SocketsMixin
      def self.included(_base)
        Yast.import "SystemdSocket"
      end

      def socket_name
        raise "Not implemented yet"
      end

      def socket
        Yast::SystemdSocket.find(socket_name)
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
