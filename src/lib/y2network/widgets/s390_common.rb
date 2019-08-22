require "cwm/common_widgets"
require "cwm/custom_widget"

module Y2Network
  module Widgets
    class S390PortNumber < CWM::ComboBox
      def initialize(settings)
        textdomain "network"

        @settings = settings
      end

      def init
        self.value = @settings.port_number.to_i
      end

      def label
        _("Port Number")
      end

      def items
        [[0, "0"], [1, "1"]]
      end

      def store
        @settings.port_number = value
      end
    end

    class S390QethOptions < CWM::InputField
      def initialize(settings)
        textdomain "network"
        @settings = settings
      end

      def label
        _("Options")
      end

      def init
        self.value = @settings.attributes
      end

      def opt
        [:hstretch]
      end

      def help
        # TRANSLATORS: S/390 dialog help for QETH Options
        _("<p>Enter any additional <b>Options</b> for this interface (separated by spaces).</p>")
      end

      def store
        @settings.attributes = value
      end
    end

    class S390IPAddressTakeover < CWM::CheckBox
      def initialize(settings)
        textdomain "network"
        @settings = settings
      end

      def init
        self.value = !!@settings.ipa_takeover
      end

      def label
        _("Enable IPA takeover")
      end

      def help
        _("<p>Select <b>Enable IPA Takeover</b> if IP address takeover should be enabled " \
          "for this interface.</p>")
      end

      def store
        @settings.ipa_takeover = value
      end
    end

    class S390Layer2 < CWM::CustomWidget
      def initialize(settings)
        textdomain "network"
        @settings = settings
        self.handle_all_events = true
      end

      def contents
        VBox(
          Left(support_widget),
          Left(mac_address_widget)
        )
      end

      def init
        refresh
      end

      def handle(event)
        case event["ID"]
        when support_widget.widget_id, mac_address_widget.widget_id
          refresh
        end

        nil
      end

    private

      def refresh
        support_widget.checked? ? mac_address_widget.enable : mac_address_widget.disable
      end

      def support_widget
        @support_widget ||= S390Layer2Support.new(@settings)
      end

      def mac_address_widget
        @mac_address_widget ||= S390Layer2Address.new(@settings)
      end
    end

    class S390Layer2Support < CWM::CheckBox
      def initialize(settings)
        textdomain "network"
        @settings = settings
      end

      def init
        self.value = !!@settings.layer2
      end

      def opt
        [:notify]
      end

      def label
        _("Enable Layer2 Support")
      end

      def help
        "<p>Select <b>Enable Layer 2 Support</b> if this card has been " \
         "configured with layer 2 support.</p>"
      end

      def store
        @settings.layer2 = value
      end
    end

    class S390Layer2Address < CWM::InputField
      def initialize(settings)
        textdomain "network"
        @settings = settings
      end

      def init
        self.value = @settings.lladdress
      end

      def opt
        [:notify]
      end

      def label
        _("Layer2 MAC Address")
      end

      def help
        _("<p>Enter the <b>Layer 2 MAC Address</b> if this card has been " \
          "configured with layer 2 support.</p>")
      end

      def store
        @settings.lladdress = value
      end
    end
  end
end
