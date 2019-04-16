require "yast"

Yast.import "NetworkInterfaces"
Yast.import "LanItems"

module Y2Network
  module Widgets
    # Mixin to help create slave (of any kind) list
    module SlaveItems
      include Yast::Logger
      include Yast::I18n

      # Builds content for slave configuration dialog (used e.g. when configuring
      # bond slaves) according the given list of item_ids (see LanItems::Items)
      #
      # @param [Array<Fixnum>] item_ids           list of indexes into LanItems::Items
      # @param [Array<String>] enslaved_ifaces    list of device names of already enslaved devices
      def slave_items_from(item_ids, enslaved_ifaces)
        raise ArgumentError, "no slave device defined" if item_ids.nil?

        textdomain "network"

        item_ids.each_with_object([]) do |item_id, items|
          dev_name = Yast::LanItems.GetDeviceName(item_id)

          next if dev_name.nil? || dev_name.empty?

          dev_type = Yast::LanItems.GetDeviceType(item_id)

          if ["tun", "tap"].include?(dev_type)
            description = Yast::NetworkInterfaces.GetDevTypeDescription(dev_type, true)
          else
            ifcfg = Yast::LanItems.GetDeviceMap(item_id) || {}

            description = TmpInclude.new.BuildDescription(
              dev_type,
              dev_name,
              ifcfg,
              [Yast::LanItems.GetLanItem(item_id)["hwinfo"] || {}]
            )

            # this conditions origin from bridge configuration
            # if enslaving a configured device then its configuration is rewritten
            # to "0.0.0.0/32"
            #
            # translators: a note that listed device is already configured
            description += " " + _("configured") if ifcfg["IPADDR"] != "0.0.0.0"
          end

          selected = false
          selected = enslaved_ifaces.include?(dev_name) if enslaved_ifaces

          description << " (Port ID: #{physical_port_id(dev_name)})" if physical_port_id?(dev_name)

          items << Yast::Term.new(:item,
            Yast::Term.new(:id, dev_name),
            "#{dev_name} - #{description}",
            selected)
        end
      end

      # TODO: just cleaner way to get a bit more complex method from include for now
      class TmpInclude
        include Yast
        include Yast::I18n

        def initialize
          Yast.include self, "network/complex.rb"
        end
      end
    end
  end
end
