require "yast"
require "cwm/common_widgets"

Yast.import "Popup"
Yast.import "UI"

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
        self.value = @settings.name
        Yast::UI.ChangeWidget(Id(widget_id), :ValidChars, @settings.name_valid_characters)
      end

      def items
        @settings.proposed_names.map do |name|
          [name, name]
        end
      end

      def validate
        if @settings.name_exists?(value)
          Yast::Popup.Error(
            format(_("Configuration name %s already exists.\nChoose a different one."), value)
          )
          focus
          return false
        end

        if !@settings.valid_name?(value)
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
        @settings.name = value
      end
    end
  end
end
