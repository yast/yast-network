require "y2network/widgets/wireless_encryption"
require "y2network/widgets/wireless_auth_mode"
require "y2network/dialogs/wireless_wep_keys"

module Y2Network
  module Widgets
    class WirelessAuth < CWM::CustomWidget
      attr_reader :settings

      def initialize(settings)
        @settings = settings
        self.handle_all_events = true
      end

      def handle(event)
        # TODO: replace point manipulation
      end

      def contents
        Frame(
          _("Wireless Authentication"),
          VBox(
            VSpacing(0.5),
            auth_mode_widget,
            VSpacing(0.2),
            # TODO Replace point to support fully EAP in one widget
            encryption_widget,
            VSpacing(0.2),
            wep_keys_widget,
            VSpacing(0.5)
          )
        )
      end

    private

      def auth_mode_widget
        @auth_mode_widget ||= Y2Network::Widgets::WirelessAuthMode.new(settings)
      end

      def encryption_widget
        @encryption_widget ||= Y2Network::Widgets::WirelessEncryption.new(settings)
      end

      def wep_keys_widget
        @wep_keys_widget ||= WirelessWepKeys.new(settings)
      end

      class WirelessWepKeys < CWM::PushButton
        def initialize(settings)
          @settings = settings
        end

        def label
          _("&WEP Keys")
        end

        def handle
          Y2Network::Dialogs::WirelessWepKeys.run(@settings)
        end
      end
    end
  end
end
