require "yast"
require "yast2/systemd/socket"

module Y2Remote
  module Modes
    # Common methods for handling systemd sockets
    module SocketBased
      def self.included(_base)
        extend Yast::I18n

        textdomain "network"
      end

      # Name of the socket to be managed
      def socket_name
        raise "Not implemented yet"
      end

      # Obtain the systemd socket itself
      #
      # @return [Yast2::Systemd::Socket, nil]
      def socket
        Yast2::Systemd::Socket.find(socket_name)
      end

      # Convenience method which return whether the socket is enabled or not
      #
      # @return [Boolean] true if the socket is enabled; false otherwise
      def enabled?
        return false unless socket
        socket.enabled?
      end

      # Convenience method to enable the systemd socket reporting an error in
      # case of failure. It return false if the service is not installed.
      #
      # @return [Boolean] return false if the systemd socket is not present or
      # not enabled; true if enabled with success
      def enable!
        return false unless socket

        if !socket.enable
          Yast::Report.Error(
            _("Enabling systemd socket %{socket} has failed") % { socket: socket_name }
          )
          return false
        end

        true
      end

      # Convenience method to disable the systemd socket reporting an error in
      # case of failure. It return false if the service is not installed.
      #
      # @return [Boolean] return false if the systemd socket is not present or
      # not disabled; true if disabled with success
      def disable!
        return false unless socket

        if enabled? && !socket.disable
          Yast::Report.Error(
            _("Disabling systemd socket %{socket} has failed") % { socket: socket_name }
          )
          return false
        end

        true
      end

      # Convenience method to stop the systemd socket reporting an error in
      # case of failure. It return false if the service is not installed.
      #
      # @return [Boolean] return false if the systemd socket is not present or
      # not stopped; true if stopped with success
      def stop!
        return false unless socket

        if !socket.stop
          Yast::Report.Error(
            _("Stopping systemd socket %{socket} has failed") % { socket: socket_name }
          )
          return false
        end

        true
      end

      # Convenience method to restart the systemd socket reporting an error in
      # case of failure. It return false if the service is not installed.
      #
      # @return [Boolean] return false if the systemd socket is not present or
      # not restarted; true if restarted with success
      def restart!
        return false unless socket && stop!

        if !socket.start
          Yast::Report.Error(
            _("Restarting systemd socket %{socket} has failed") % { socket: socket_name }
          )
          return false
        end

        true
      end
    end
  end
end
