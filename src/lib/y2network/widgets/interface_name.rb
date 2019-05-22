require "yast"
require "cwm/common_widgets"

Yast.import "NetworkInterfaces"
Yast.import "LanItems"

module Y2Network
  module Widgets
    class InterfaceName < CWM::ComboBox
      def initialize(settings)
        textdomain "network"

        @settings = settings
      end

      def label
        _("&Configuration Name")
      end

      def opt
        [:editable, :hstretch]
      end

      def help
        # FIXME: missing. Try to explain what it affect. Especially for fake devices
        ""
      end

      def init
        self.value = @settings["IFCFGID"]
        Yast::UI.ChangeWidget(Id(widget_id), :ValidChars, Yast::NetworkInterfaces.ValidCharsIfcfg)
      end

      # how many device names is proposed in widget
      NEW_DEVICES_COUNT = 10
      def items
        Yast::LanItems.new_type_devices(@settings["IFCFGTYPE"], NEW_DEVICES_COUNT).map do |name|
          [name, name]
        end
      end

      def validate
        # name have to be unique
        if Yast::NetworkInterfaces.List("").include?(value)
          Yast::Popup.Error(
            format(_("Configuration name %s already exists.\nChoose a different one."), value)
          )
          focus
          return false
        end

        # 16 is the kernel limit on interface name size (IFNAMSIZ)
        if value !~ /^[[:alnum:]._:-]{1,15}\z/
          # TODO: write in popup what is limitations
          Yast::Popup.Error(
            format(_("Configuration name %s is invalid.\nChoose a different one."), value)
          )

          focus
          return false
        end

        true
      end

      def store
        @settings["IFCFGID"] = value
      end
    end
  end
end
