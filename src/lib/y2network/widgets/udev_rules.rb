require "yast"
require "cwm/custom_widget"
require "network/edit_nic_name"

Yast.import "UI"

module Y2Network
  module Widgets
    class UdevRules < CWM::CustomWidget
      def initialize(settings)
        textdomain "network"
        @settings = settings
      end

      def contents
        Frame(
          _("Udev Rules"),
          HBox(
            InputField(Id(:udev_rules_name), Opt(:hstretch, :disabled), _("Device Name"), ""),
            PushButton(Id(:udev_rules_change), _("Change"))
          )
        )
      end

      def init
        self.value = @settings.udev_name
      end

      def handle
        self.value = Yast::EditNicName.new(@settings).run

        nil
      end

      def store
        # TODO: nothing to do as done in EditNicName which looks wrong
      end

      def value=(name)
        Yast::UI.ChangeWidget(Id(:udev_rules_name), :Value, name)
      end

      def value
        Yast::UI.QueryWidget(Id(:udev_rules_name), :Value)
      end

      def help
        _(
          "<p><b>Udev Rules</b> are rules for the kernel device manager that allow\n" \
            "associating the MAC address or BusID of the network device with its name (for\n" \
            "example, eth1, wlan0 ) and assures a persistent device name upon reboot.\n"
        )
      end
    end
  end
end
