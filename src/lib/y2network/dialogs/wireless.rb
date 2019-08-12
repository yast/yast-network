require "yast"
require "cwm/dialog"
require "y2network/widgets/wireless"
require "y2network/dialogs/wireless_eap"

module Y2Network
  module Dialogs
    class Wireless < CWM::Dialog
      # @param settings [InterfaceBuilder] object holding interface configuration
      #   modified by the dialog.
      def initialize(settings)
        @settings = settings

        textdomain "network"
      end

      def title
        _("Wireless Network Card Configuration")
      end

      def contents
        HBox(
          HSpacing(4),
          wireless_widget,
          HSpacing(4)
        )
      end

      def settings
        @settings
      end

      def run
        ret = super
        if settings.auth_mode == "wpa-eap"
          ret = Y2Network::Dialogs::WirelessEap.new(settings).run
          return :redraw if ret == :back
        end

        settings.save if ret == :next
      end

    private

      def wireless_widget
        @wireless_widget ||= Y2Network::Widgets::Wireless.new(settings)
      end
    end
  end
end
