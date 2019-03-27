Yast.import "IP"
Yast.import "Popup"

require "ipaddr"

require "cwm/common_widgets"
require "cwm/custom_widget"

module Y2Network
  module Widgets
    class Destination < CWM::CustomWidget
      # @param route [Y2Network::Route] route to modify by widget
      def initialize(route)
        textdomain "network"

        @route = route
      end

      def contents
        HBox(
          CheckBox(Id(:default), Opt(:notify, :hstretch), _("Default Route")),
          InputField(Id(:destination), Opt(:hstretch), _("&Destination"))
        )
      end

      def help
        # TODO: original also does not have help, so write new one
        ""
      end

      def handle
        default_value ? disable_destination : enable_destination

        nil
      end

      def init
        Yast::UI.ChangeWidget(Id(:destination), :ValidChars, Yast::IP.ValidChars + "/")
        val = @route.to
        Yast::UI.ChangeWidget(Id(:default), :Value, val == :default)
        Yast::UI.ChangeWidget(Id(:destination), :Value, (val.to_s + "/" + val.prefix.to_s) ) if val != :default
        handle
      end

      def validate
        return true if valid_destination?

        Yast::Popup.Error(_("Destination is invalid."))
        Yast::UI.SetFocus(Id(:destination))
        false
      end

      def store
        @route.to = default_value ? :default : IPAddr.new(destination_value)
      end

    private

      def default_value
        Yast::UI.QueryWidget(Id(:default), :Value)
      end

      def destination_value
        Yast::UI.QueryWidget(Id(:destination), :Value)
      end

      def enable_destination
        Yast::UI.ChangeWidget(Id(:destination), :Enabled, true)
      end

      def disable_destination
        Yast::UI.ChangeWidget(Id(:destination), :Enabled, false)
      end

      # Validates user's input obtained from destination field
      def valid_destination?
        return true if default_value

        ip = destination_value[/^[^\/]+/]
        Yast::IP.Check(ip)
      end
    end
  end
end
