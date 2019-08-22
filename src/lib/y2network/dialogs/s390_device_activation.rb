require "cwm/dialog"
require "y2network/widgets/s390_common"
require "y2network/widgets/s390_channels"

module Y2Network
  module Dialogs
    class S390DeviceActivation < CWM::Dialog
      def initialize(settings)
        textdomain "network"

        @settings = settings
        @settings.proposal
      end

      def title
        _("S/390 Network Card Configuration")
      end

      def contents
        HBox(
          HSpacing(6),
          Frame(
            _("S/390 Device Settings"),
            HBox(
              HSpacing(2),
              VBox(
                VSpacing(1),
                HBox(
                  s390_port_number,
                  HSpacing(1),
                  s390_options
                ),
                VSpacing(1),
                Left(s390_ip_takeover),
                VSpacing(1),
                Left(s390_layer2),
                VSpacing(1),
                s390_channels
              ),
              HSpacing(2)
            )
          ),
          HSpacing(6)
        )
      end

      def abort_handler
        Yast::Popup.YesNo("Really abort?")
      end

    private

      def s390_port_number
        Y2Network::Widgets::S390PortNumber.new(@settings)
      end

      def s390_options
        Y2Network::Widgets::S390QethOptions.new(@settings)
      end

      def s390_ip_takeover
        Y2Network::Widgets::S390IPAddressTakeover.new(@settings)
      end

      def s390_channels
        Y2Network::Widgets::S390Channels.new(@settings)
      end

      def s390_layer2
        Y2Network::Widgets::S390Layer2.new(@settings)
      end
    end
  end
end
