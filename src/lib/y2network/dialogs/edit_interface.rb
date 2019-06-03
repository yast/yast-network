require "cwm/dialog"

require "y2network/widgets/address_tab.rb"
require "y2network/widgets/bond_slaves_tab.rb"
require "y2network/widgets/bridge_slaves_tab.rb"
require "y2network/widgets/general_tab.rb"
require "y2network/widgets/hardware_tab.rb"

Yast.import "LanItems"
Yast.import "Label"

module Y2Network
  module Dialogs
    # Dialog to Edit Interface.
    class EditInterface < CWM::Dialog
      # @param settings [InterfaceBuilder] object holding interface configuration
      #   modified by dialog.
      def initialize(settings)
        @settings = settings

        textdomain "network"
      end

      def title
        _("Network Card Setup")
      end

      def contents
        # if there is addr, make it initial
        addr_tab = Widgets::AddressTab.new(@settings)
        addr_tab.initial = true

        tabs = case @settings.type
        when "vlan"
          [Widgets::GeneralTab.new(@settings), addr_tab]
        when "tun", "tap"
          [addr_tab]
        when "br"
          [Widgets::GeneralTab.new(@settings), addr_tab, Widgets::BridgePorts.new(@settings)]
        when "bond"
          [Widgets::GeneralTab.new(@settings), addr_tab, Widgets::HardwareTab.new(@settings),
           Widgets::BondSlavesTab.new(@settings)]
        else
          [Widgets::GeneralTab.new(@settings), addr_tab, Widgets::HardwareTab.new(@settings)]
        end

        VBox(CWM::Tabs.new(*tabs))
      end

      def abort_button
        Yast::Label.CancelButton
      end

      def back_button
        # TODO: decide operation based on builder
        Yast::LanItems.operation == :add ? Yast::Label.BackButton : ""
      end
    end
  end
end
