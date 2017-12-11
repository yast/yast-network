require "y2remote/modes/base"
require "y2remote/modes/socket_based"

module Y2Remote
  module Modes
    # Class responsible of handle the systemd socket for vnc web access
    class Web < Base
      include SocketBased

      # Name of the systemd socket
      SOCKET   = "xvnc-novnc".freeze
      # Packages required by the systemd socket
      PACKAGES = ["xorg-x11-Xvnc-novnc"].freeze

      # Return a list of names of the required packages of the running mode
      #
      # @return [Array<String>] list of packages required by the service
      def required_packages
        PACKAGES
      end

      # Name of the socket
      #
      # @return [String] socket name
      def socket_name
        SOCKET
      end
    end
  end
end
