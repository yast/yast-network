Yast.import "Netmask"

require "cwm/common_widgets"

module Y2Network
  module Widgets
    class Netmask < CWM::InputField
     # @param route route object to get and store netmask value
     # TODO: I expect it will be useful on multiple places, so we need find way how to store it
      def initialize(route)
        textdomain "network"
      end

      def label
        _("&Netmask")
      end

      def help
        # TODO: original also does not have help
        ""
      end

      def opt
        [:hstretch]
      end

      def init
        Yast::UI.ChangeWidget(Id(widget_id), :ValidChars, Yast::Netmask.ValidChars +"-/")
        # TODO: init from route object
      end

      def validate
        return true if valid_netmask?

        Yast::Popup.Error(_("Subnetmask is invalid."))
        focus
        false
      end

    private

      # Validates user's input obtained from Netmask field
      #
      # It currently allows to use netmask for IPv4 (e.g. 255.0.0.0) or
      # prefix length. If prefix length is used it has to start with '/'.
      # For IPv6 network, only prefix length is allowed.
      #
      # @param [String] netmask or /<prefix length>
      def valid_netmask?
        netmask = value
        return false if netmask.nil? || netmask.empty?
        return true if Netmask.Check4(netmask)

        if netmask.start_with?("/")
          return true if netmask[1..-1].to_i.between?(1, 128)
        end

        false
      end
    end
  end
end
