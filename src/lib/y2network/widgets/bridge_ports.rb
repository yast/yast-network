require "yast"
require "cwm/common_widgets"
require "y2network/widgets/slave_items"

Yast.import "Label"
Yast.import "LanItems"
Yast.import "NetworkInterfaces"
Yast.import "Popup"
Yast.import "UI"

module Y2Network
  module Widgets
    class BridgePorts < CWM::MultiSelectionBox
      include SlaveItems

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
        br_ports = @settings["BRIDGE_PORTS"]
        items = slave_items_from(
          Yast::LanItems.GetBondableInterfaces(Yast::LanItems.GetCurrentName),
          br_ports
        )

        # it is list of Items, so cannot use `change_items` helper
        Yast::UI.ChangeWidget(Id(widget_id), :Items, items)
      end

      # Default function to store the value of slave devices box.
      def store
        @settings["BRIDGE_PORTS"] = value
      end

      # Validates created bridge. Currently just prevent the user to create a
      # bridge with already configured interfaces
      #
      # @return true if valid or user decision if not
      def validate
        configurations = Yast::NetworkInterfaces.FilterDevices("netcard")
        netcard_types = (Yast::NetworkInterfaces.CardRegex["netcard"] || "").split("|")

        confs = netcard_types.reduce([]) do |res, devtype|
          res.concat((configurations[devtype] || {}).keys)
        end

        valid = true

        (value || []).each do |device|
          next if !confs.include?(device)

          dev_type = Yast::NetworkInterfaces.GetType(device)
          ifcfg_conf = configurations[dev_type][device]

          next if ifcfg_conf["BOOTPROTO"] == "none"

          valid = Yast::Popup.ContinueCancel(
            _(
              "At least one selected device is already configured.\nAdapt the configuration for bridge?\n"
            )
          )
          break
        end
        valid
      end
    end
  end
end
