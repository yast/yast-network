Yast.import "Netmask"

require "cwm/common_widgets"

module Y2Network
  module Widgets
    class Netmask < CWM::InputField
      # @param route route object to get and store netmask value
      # TODO: so far not clear if we should do it
      # separately or keep prefix in destination as already. So not working now
      def initialize(route)
        textdomain "network"

        @route = route
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
        Yast::UI.ChangeWidget(Id(widget_id), :ValidChars, Yast::Netmask.ValidChars + "-/")
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
