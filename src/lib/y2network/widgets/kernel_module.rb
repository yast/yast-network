require "yast"

require "cwm/common_widgets"

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

      def items
        @settings.kernel_modules.map do |i|
          [i, i]
        end
      end

      def init
        self.value = @settings.driver unless @settings.driver.empty?
      end

      def store
        @settings.driver = value
      end
    end
  end
end
