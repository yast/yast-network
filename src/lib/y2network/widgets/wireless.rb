require "y2network/widgets/wireless_essid"
require "y2network/widgets/wireless_eap"
require "y2network/widgets/wireless_encryption"
require "y2network/widgets/wireless_mode"
require "y2network/widgets/wireless_auth_mode"
require "y2network/dialogs/wireless_wep_keys"
require "y2network/dialogs/wireless_expert_settings"

module Y2Network
  module Widgets
    class Wireless < CWM::CustomWidget
      attr_reader :settings

      def initialize(settings)
        @settings = settings
        self.handle_all_events = true
      end

      def init
      end

      def handle(event)
        case event["ID"]
        when auth_mode_widget.widget_id
          refresh
        when mode_widget.widget_id
          refresh
        end

        nil
      end

      def contents
        VBox(
          VSpacing(0.5),
          # Frame label
          Frame(
            _("Wireless Device Settings"),
            HBox(
              HSpacing(2),
              VBox(
                VSpacing(0.5),
                # ComboBox label
                mode_widget,
                VSpacing(0.2),
                # Text entry label
                essid_widget,
                VSpacing(0.2),
                auth_mode_widget,
                VSpacing(0.2),
                encryption_widget,
                VSpacing(0.5)
              ),
              HSpacing(2)
            )
          ),
          VSpacing(0.5),
          HBox(
            expert_settings_widget,
            HSpacing(0.5),
            wep_keys_widget
          ),
          VSpacing(0.5)
        )
      end

    private

      def refresh
        wep_keys_widget.disable
        encryption_widget.enable
        case auth_mode_widget.value
        when "wpa-eap"
          mode_widget.value = "Managed"
          encryption_widget.disable
        when "wpa-psk"
          mode_widget.value = "Managed"
        when "wep"
          encryption_widget.disable
          wep_keys_widget.enable
        when "no-encryption"
          encryption_widget.disable
        end
      end

      def mode_widget
        @mode_widget ||= Y2Network::Widgets::WirelessMode.new(settings)
      end

      def essid_widget
        @essid_widget ||= Y2Network::Widgets::WirelessEssid.new(settings)
      end

      def auth_mode_widget
        @auth_mode_widget ||= Y2Network::Widgets::WirelessAuthMode.new(settings)
      end

      def encryption_widget
        @encryption_widget ||= Y2Network::Widgets::WirelessEncryption.new(settings)
      end

      def expert_settings_widget
        @expert_settings_widget ||= Y2Network::Widgets::WirelessExpertSettings.new(settings)
      end

      def wep_keys_widget
        @wep_keys_widget ||= Y2Network::Widgets::WirelessWepKeys.new(settings)
      end
    end

    class WirelessExpertSettings < CWM::PushButton
      def initialize(settings)
        @settings = settings
      end

      def label
        _("E&xpert Settings")
      end

      def handle
        Y2Network::Dialogs::WirelessExpertSettings.new(@settings).run

        nil
      end
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
