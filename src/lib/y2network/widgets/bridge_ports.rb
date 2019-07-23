require "yast"
require "cwm/common_widgets"
require "y2network/widgets/slave_items"

Yast.import "Label"
Yast.import "Popup"
Yast.import "UI"

module Y2Network
  module Widgets
    class BridgePorts < CWM::MultiSelectionBox
      include SlaveItems

      # @param [Y2Network::InterfaceConfigBuilders::Bridge] settings
      def initialize(settings)
        textdomain "network"
        @settings = settings
      end

      def label
        _("Bridged Devices")
      end

      def help
        # TODO: write it
        ""
      end

      # Default function to init the value of slave devices box for bridging.
      def init
        br_ports = @settings.ports
        items = slave_items_from(
          @settings.bridgeable_interfaces.map(&:name),
          br_ports
        )

        # it is list of Items, so cannot use `change_items` helper
        Yast::UI.ChangeWidget(Id(widget_id), :Items, items)
      end

      # Default function to store the value of slave devices box.
      def store
        @settings.ports = value
      end

      # Validates created bridge. Currently just prevent the user to create a
      # bridge with already configured interfaces
      #
      # @return true if valid or user decision if not
      def validate
        if @settings.already_configured?(value || [])
          return Yast::Popup.ContinueCancel(
            _(
              "At least one selected device is already configured.\nAdapt the configuration for bridge?\n"
            )
          )
        else
          true
        end
      end
    end
  end
end
