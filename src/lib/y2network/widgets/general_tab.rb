require "yast"
require "cwm/tabs"

Yast.import "LanItems"

# used widgets
require "y2network/widgets/interface_name"
require "y2network/widgets/udev_rules"
require "y2network/widgets/startmode"
require "y2network/widgets/ifplugd_priority"
require "y2network/widgets/firewall_zone"
require "y2network/widgets/ipoib_mode"
require "y2network/widgets/mtu"

module Y2Network
  module Widgets
    class GeneralTab < CWM::Tab
      def initialize(settings)
        textdomain "network"

        @settings = settings
      end

      def label
        _("&General")
      end

      def contents
        ifplugd_widget = IfplugdPriority.new(@settings)
        MarginBox(
          1,
          0,
          VBox(
            MarginBox(
              1,
              0,
              VBox(
                # FIXME: udev rules for anything without hwinfo is wrong
                Yast::LanItems.operation == :add ? InterfaceName.new(@settings) : UdevRules.new(@settings),
                Frame(
                  _("Device Activation"),
                  HBox(Startmode.new(@settings, ifplugd_widget), ifplugd_widget, HStretch())
                ),
                VSpacing(0.4),
                # TODO: Frame(_("Firewall Zone"), HBox("FWZONE", HStretch())),
                VSpacing(0.4),
                type == "ib" ? HBox(IPoIBMode.new(@settings)) : Empty(),
                type == "ib" ? VSpacing(0.4) : Empty(),
                Frame(
                  _("Maximum Transfer Unit (MTU)"),
                  HBox(MTU.new(@settings), HStretch())
                ),
                VStretch()
              )
            )
          )
        )
      end

      def type
        @settings["IFCFGTYPE"]
      end
    end
  end
end
