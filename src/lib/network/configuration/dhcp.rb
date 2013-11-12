require "network/configuration/base"

require "yast"

Yast.import "NetworkInterfaces"
Yast.import "LanItems"

module Network
  module Configuration
    class DHCP
      def save
        if !Yast::LanItems.FindAndSelect(device.name)
          raise "Failed to save configuration for device #{device.name}"
        end

        Yast::LanItems.SetItem

        #tricky part if ifcfg is not set
        # yes, this code smell and show bad API of LanItems
        if (Yast::LanItems.getCurrentItem["ifcfg"] || "").empty?
          Yast::NetworkInterfaces.Add
          Yast::LanItems.operation = :edit
          current = Yast::LanItems.Items[Yast::LanItems.current]
          current["ifcfg"] = device.name
        end

        Yast::LanItems.bootproto = "dhcp"
        Yast::LanItems.ipaddr = ""
        Yast::LanItems.netmask = ""
        # TODO make it attribute when needed
        Yast::LanItems.startmode = "auto"
        Yast::LanItems.Commit

        Yast::NetworkInterfaces.Write(device.name)
      end
    end
  end
end
