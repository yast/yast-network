require "yast"
require "cwm/dialog"
require "y2network/widgets/wireless"
require "y2network/widgets/wireless_expert"

module Y2Network
  module Dialogs
    class WirelessExpertSettings < CWM::Dialog
      # @param settings [InterfaceBuilder] object holding interface configuration
      #   modified by the dialog.
      def initialize(settings)
        @settings = settings

        textdomain "network"
      end

      def title
        _("Wireless Expert Settings")
      end

      def contents
        HBox(
          HSpacing(4),
          VBox(
            VSpacing(0.5),
            Frame(
              _("Wireless Expert Settings"),
              HBox(
                HSpacing(2),
                VBox(
                  VSpacing(1),
                  channel_widget,
                  VSpacing(0.2),
                  bitrate_widget,
                  VSpacing(0.2),
                  access_point_widget,
                  VSpacing(0.2),
                  Left(power_management_widget),
                  VSpacing(0.2),
                  Left(ap_scan_mode_widget),
                  VSpacing(1)
                ),
                HSpacing(2)
              )
            ),
            VSpacing(0.5)
          ),
          HSpacing(4)
        )
      end

      def help
        # Wireless expert dialog help 1/5
        _(
          "<p>Here, set additional configuration parameters\n(rarely needed).</p>"
        ) +
          # Wireless expert dialog help 2/5
          _(
            "<p>To use your wireless LAN card in master or ad-hoc mode,\n" \
              "set the <b>Channel</b> the card should use here. This is not needed\n" \
              "for managed mode--the card will hop through the channels searching for access\n" \
              "points in that case.</p>\n"
          ) +
          # Wireless expert dialog help 3/5
          _(
            "<p>In some rare cases, you may want to set a transmission\n<b>Bit Rate</b> explicitly. The default is to go as fast as possible.</p>"
          ) +
          # Wireless expert dialog help 4/5
          _(
            "<p>In an environment with multiple <b>Access Points</b>, you may want to\ndefine the one to which to connect by entering its MAC address.</p>"
          ) +
          # Wireless expert dialog help 5/5
          _(
            "<p><b>Use Power Management</b> enables power saving mechanisms.\n" \
              "This is generally a good idea, especially if you are a laptop user and may\n" \
              "be disconnected from AC power.</p>\n"
          )
        end

    private

      def channel_widget
        @channel_widget ||= Y2Network::Widgets::WirelessChannel.new(@settings)
      end

      def bitrate_widget
        @bitrate_widget ||= Y2Network::Widgets::WirelessBitRate.new(@settings)
      end

      def access_point_widget
        @access_point_widget ||= Y2Network::Widgets::WirelessAccessPoint.new(@settings)
      end

      def power_management_widget
        @access_power_widget ||= Y2Network::Widgets::WirelessPowerManagement.new(@settings)
      end

      def ap_scan_mode_widget
        @ap_scan_mode_widget ||= Y2Network::Widgets::WirelessAPScanMode.new(@settings)
      end
    end
  end
end
