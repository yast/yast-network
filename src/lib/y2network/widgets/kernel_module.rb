require "yast"

require "cwm/common_widgets"

Yast.import "LanItems"

module Y2Network
  module Widgets
    class KernelModule < CWM::ComboBox
      def initialize(settings)
        textdomain "network"
        @settings = settings
      end

      def label
        _("&Module Name")
      end

      def help
        "<p><b>Kernel Module</b>. Enter the kernel module (driver) name \n" \
          "for your network device here. If the device is already configured, see if there is more than one driver available for\n" \
          "your device in the drop-down list. If necessary, choose a driver from the list, but usually the default value works.</p>\n"
      end

      def opt
        [:editable]
      end

      def init
        items = Yast::LanItems.GetItemModules("").map do |i|
          [i, i]
        end
        change_items(items)

        driver = Yast::Ops.get_string(Yast::LanItems.getCurrentItem, ["udev", "driver"], "")
        self.value = driver unless driver.empty?
      end

      def store
        Yast::LanItems.setDriver(value)
      end
    end
  end
end
