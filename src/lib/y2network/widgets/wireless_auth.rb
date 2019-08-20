require "cwm/custom_widget"
require "cwm/replace_point"

require "y2network/dialogs/wireless_wep_keys"
require "y2network/widgets/wireless_auth_mode"
require "y2network/widgets/wireless_eap"
require "y2network/widgets/wireless_password"

module Y2Network
  module Widgets
    # Top level widget for wireless authentication. It changes content dynamically depending
    # on selected authentication method.
    class WirelessAuth < CWM::CustomWidget
      attr_reader :settings

      # @param settings [Y2network::InterfaceConfigBuilder]
      def initialize(settings)
        @settings = settings
        self.handle_all_events = true
      end

      def init
        refresh
      end

      def handle(event)
        return if event["ID"] != auth_mode_widget.widget_id

        refresh
        nil
      end

      def contents
        Frame(
          _("Wireless Authentication"),
          VBox(
            VSpacing(0.5),
            auth_mode_widget,
            VSpacing(0.2),
            replace_widget,
            VSpacing(0.5)
          )
        )
      end

    private

      def refresh
        case auth_mode_widget.value
        when "no-encryption", "open" then replace_widget.replace(empty_auth_widget)
        when "sharedkey" then replace_widget.replace(wep_keys_widget)
        when "wpa-psk" then replace_widget.replace(encryption_widget)
        when "wpa-eap" then replace_widget.replace(eap_widget)
        else
          raise "invalid value #{auth_mode_widget.value.inspect}"
        end
      end

      def replace_widget
        @replace_widget ||= CWM::ReplacePoint.new(id: "wireless_replace_point", widget: empty_auth_widget)
      end

      def empty_auth_widget
        @empty_auth ||= CWM::Empty.new("wireless_empty")
      end

      def auth_mode_widget
        @auth_mode_widget ||= WirelessAuthMode.new(settings)
      end

      def encryption_widget
        @encryption_widget ||= WirelessPassword.new(settings)
      end

      def wep_keys_widget
        @wep_keys_widget ||= WirelessWepKeys.new(settings)
      end

      def eap_widget
        @eap_widget ||= WirelessEap.new(settings)
      end

      # Button for showing WEP Keys dialog
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
