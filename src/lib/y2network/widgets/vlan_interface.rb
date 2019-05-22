require "cwm/common_widgets"

Yast.import "LanItems"
Yast.import "NetworkInterfaces"

module Y2Network
  module Widgets
    class VlanInterface < CWM::ComboBox
      def initialize(config)
        textdomain "network"

        @config = config
      end

      def label
        _("Real Interface for &VLAN")
      end

      def help
        # TODO: previously not exist, so write it
      end

      def init
        # TODO: items in own method. Not possible now as widget is cached in include
        items = []
        # unconfigured devices
        Yast::LanItems.Items.each_value do |lan_item|
          next unless (lan_item["ifcfg"] || "").empty?
          dev_name = Yast::Ops.get_string(a, ["hwinfo", "dev_name"], "")
          items << [dev_name, dev_name]
        end
        # configured devices
        configurations = Yast::NetworkInterfaces.FilterDevices("netcard")
        # TODO: API looks horrible
        Yast::NetworkInterfaces.CardRegex["netcard"].split("|").each do |devtype|
          (configurations[devtype] || {}).each_key do |devname|
            next if Yast::NetworkInterfaces.GetType(devname) == "vlan"

            items << [devname, "#{devname} - #{Yast::Ops.get_string(configurations, [devtype, devname, "NAME"], "")}"]
          end
        end
        change_items(items)
        # TODO: END

        self.value = @config["ETHERDEVICE"] if @config["ETHERDEVICE"]
      end

      def store
        @config["ETHERDEVICE"] = value
      end
    end
  end
end
