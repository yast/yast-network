require "yast"
require "cwm/custom_widget"
require "y2network/widgets/slave_items"

Yast.import "UI"
Yast.import "LanItems"

module Y2Network
  module Widgets
    class BondSlave < CWM::CustomWidget
      include SlaveItems

      def initialize(settings)
        textdomain "network"
        @settings = settings
      end

      def contents
        Frame(
          _("Bond Slaves and Order"),
          VBox(
            MultiSelectionBox(Id(:bond_slaves_items), Opt(:notify), "", []),
            HBox(
              PushButton(Id(:bond_slaves_up), Opt(:disabled), _("Up")),
              PushButton(Id(:bond_slaves_down), Opt(:disabled), _("Down"))
            )
          )
        )
      end

      def handle(event)
        if event["EventReason"] == "SelectionChanged"
          enable_slave_buttons
        elsif event["EventReason"] == "Activated" && event["WidgetClass"] == :PushButton
          items = ui_items || []
          current = value.to_s
          index = value_index
          case event["ID"]
          when :up
            items[index], items[index - 1] = items[index - 1], items[index]
          when :down
            items[index], items[index + 1] = items[index + 1], items[index]
          else
            log.warn("unknown action #{event["ID"]}")
            return nil
          end
          UI.ChangeWidget(:bond_slaves_items, :Items, items)
          UI.ChangeWidget(:bond_slaves_items, :CurrentItem, current)
          enable_slave_buttons
        else
          log.debug("event:#{event}")
        end

        nil
      end

      def help
        # TODO: write it
        ""
      end

      # Default function to init the value of slave devices box for bonding.
      def init
        # TODO: why? it should respect previous @settings, not?
        @settings["SLAVES"] = Yast::LanItems.bond_slaves || []

        @settings["BONDOPTION"] = Yast::LanItems.bond_option

        items = slave_items_from(
          Yast::LanItems.GetBondableInterfaces(Yast::LanItems.GetCurrentName),
          Yast::LanItems.bond_slaves
        )

        # reorder the items
        l1, l2 = items.partition { |t| @settings["SLAVES"].include? t[0][0] }

        items = l1 + l2.sort_by { |t| justify_dev_name(t[0][0]) }

        Yast::UI.ChangeWidget(:bond_slaves_items, :Items, items)

        Yast::UI.ChangeWidget(
          :bond_slaves_items,
          :SelectedItems,
          @settings["SLAVES"]
        )

        enable_slave_buttons

        nil
      end

      # Default function to store the value of slave devices box.
      def store
        configured_slaves = @settings["SLAVES"] || []

        selected_slaves = Yast::UI.QueryWidget(:bond_slaves_items, :SelectedItems) || []

        @settings["SLAVES"] = selected_slaves

        # XXX: Hmm, it stores different widget? This is dark cwm hack and hidden dependency
        # that both widget have to be used together
#        @settings["BONDOPTION"] = Yast::UI.QueryWidget(Id("BONDOPTION"), :Value).to_s

        Yast::LanItems.bond_slaves = @settings["SLAVES"]
#        LanItems.bond_option = @settings["BONDOPTION"]

        # create list of "unconfigured" slaves
        new_slaves = @settings["SLAVES"].select do |slave|
          !configured_slaves.include? slave
        end

        Yast::Lan.autoconf_slaves = (Yast::Lan.autoconf_slaves + new_slaves).uniq.sort

        nil
      end

      # Validates created bonding. Currently just prevent the user to create a
      # bond with more than one interface sharing the same physical port id
      #
      # @return true if valid or user decision if not
      def validate
        selected_slaves = Yast::UI.QueryWidget(:bond_slaves_items, :SelectedItems) || []

        physical_ports = repeated_physical_port_ids(selected_slaves)

        physical_ports.empty? ? true : continue_with_duplicates?(physical_ports)
      end

      def value
        # TODO: it is multiselection, so does it make sense?
        Yast::UI.QueryWidget(:slave_bonds_items, :CurrentItem)
      end

      def ui_items
        Yast::UI.QueryWidget(:slave_bonds_items, :Items) || []
      end

      def value_index
        ui_items.index { |i| i[0] == Id(value) }
      end

      def enable_slave_buttons
        if value_index
          Yast::UI.ChangeWidget(:slave_bonds_up, :Enabled, value_index > 0)
          Yast::UI.ChangeWidget(:slave_bonds_down, :Enabled, value_index < ui_items.size - 1)
        else
          Yast::UI.ChangeWidget(:slave_bonds_up, :Enabled, false)
          Yast::UI.ChangeWidget(:slave_bonds_down, :Enabled, false)
        end
      end

      # A helper for sort devices by name. It justify at right with 0's numeric parts of given
      # device name until 5 digits.
      #
      # TODO: should not be in CWM
      # ==== Examples
      #
      #   justify_dev_name("eth0") # => "eth00000"
      #   justify_dev_name("eth111") # => "eth00111"
      #   justify_dev_name("enp0s25") # => "enp00000s00025"
      #
      # @param name [String] device name
      # @return [String] given name with numbers justified at right
      def justify_dev_name(name)
        splited_dev_name = name.scan(/\p{Alpha}+|\p{Digit}+/)
        splited_dev_name.map! do |d|
          if d =~ /\p{Digit}+/
            d.rjust(5, "0")
          else
            d
          end
        end.join
      end

      # Given a list of device names returns a hash of physical port ids mapping
      # device names if at least two devices shared the same physical port id
      # TODO: should not be in CWM
      #
      # @param slaves [Array<String>] bonding slaves
      # @return [Hash{String => Array<String>}] of duplicated physical port ids
      def repeated_physical_port_ids(slaves)
        physical_port_ids = {}

        slaves.each do |slave|
          if physical_port_id?(slave)
            p = physical_port_ids[physical_port_id(slave)] ||= []
            p << slave
          end
        end

        physical_port_ids.select! { |_k, v| v.size > 1 }

        physical_port_ids
      end

      # With NPAR and SR-IOV capabilities, one device could divide a ethernet
      # port in various. If the driver module support it, we can check the phys
      # port id via sysfs reading the /sys/class/net/$dev_name/phys_port_id
      # TODO: should not be in CWM
      #
      # @param dev_name [String] device name to check
      # @return [String] physical port id if supported or a empty string if not
      def physical_port_id(dev_name)
        Yast::SCR.Read(
          Yast::Path.new(".target.string"),
          "/sys/class/net/#{dev_name}/phys_port_id"
        ).to_s.strip
      end

      # @return [boolean] true if the physical port id is not empty
      # @see #physical_port_id
      def physical_port_id?(dev_name)
        !physical_port_id(dev_name).empty?
      end
    end
  end
end
