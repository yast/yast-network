require "y2remote/modes/base"
require "y2remote/modes/socket_based"

Yast.import "OSRelease"

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
        PACKAGES + recommended_packages
      end

      # Name of the socket
      #
      # @return [String] socket name
      def socket_name
        SOCKET
      end

      # Return a list of recommended packages names
      #
      # VNC web access relies on python-websockify, which has dependency on some other python
      # packages related to Web Cryptography API. Those packages are actually marked as
      # "recommended" but are necessaries to have enabled VNC with web support. In addition,
      # packages are not the same for SLE and openSUSE (bsc#1131024).
      #
      # @return [Array<String>] lisf of "recommended" packages names
      def recommended_packages
        if Yast::OSRelease.ReleaseInformation =~ /openSUSE/
          ["python-jwcrypto"]
        else
          ["python-PyJWT", "python-cryptography"]
        end
      end
    end
  end
end
