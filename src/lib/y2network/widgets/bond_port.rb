# Copyright (c) [2019] SUSE LLC
#
# All Rights Reserved.
#
# This program is free software; you can redistribute it and/or modify it
# under the terms of version 2 of the GNU General Public License as published
# by the Free Software Foundation.
#
# This program is distributed in the hope that it will be useful, but WITHOUT
# ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or
# FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License for
# more details.
#
# You should have received a copy of the GNU General Public License along
# with this program; if not, contact SUSE LLC.
#
# To contact SUSE LLC about this file by physical or electronic mail, you may
# find current contact information at www.suse.com.

require "ui/text_helpers"
require "yast"
require "cwm/custom_widget"
require "y2network/widgets/port_items"

Yast.import "Label"
Yast.import "Lan"
Yast.import "Popup"
Yast.import "UI"

module Y2Network
  module Widgets
    class BondPort < CWM::CustomWidget
      include PortItems
      include ::UI::TextHelpers

      def initialize(settings)
        super()
        textdomain "network"
        @settings = settings
      end

      def contents
        Frame(
          _("Bond Ports and Order"),
          VBox(
            MultiSelectionBox(Id(:bond_ports_items), Opt(:notify), "", []),
            HBox(
              # TRANSLATORS: this means "move this line upwards"
              PushButton(Id(:bond_ports_up), Opt(:disabled), _("Up")),
              # TRANSLATORS: this means "move this line downwards"
              PushButton(Id(:bond_ports_down), Opt(:disabled), _("Down"))
            )
          )
        )
      end

      def handle(event)
        if event["EventReason"] == "SelectionChanged"
          enable_position_buttons
        elsif event["EventReason"] == "Activated" && event["WidgetClass"] == :PushButton
          items = ui_items || []
          current = value.to_s
          index = value_index
          case event["ID"]
          when :bond_ports_up
            items[index], items[index - 1] = items[index - 1], items[index]
          when :bond_ports_down
            items[index], items[index + 1] = items[index + 1], items[index]
          else
            log.warn("unknown action #{event["ID"]}")
            return nil
          end
          Yast::UI.ChangeWidget(:bond_ports_items, :Items, items)
          Yast::UI.ChangeWidget(:bond_ports_items, :CurrentItem, current)
          enable_position_buttons
        else
          log.debug("event:#{event}")
        end

        nil
      end

      def help
        # TODO: write it
        _(
          "<p>Select a devices for including into the bond.\n" \
          "Only devices with the device activation set to <b>Never</b> " \
          "and with <b>No Address Setup</b> are available.</p>"
        )
      end

      # Default function to init the value of port devices box for bonding.
      def init
        ports = @settings.ports
        # TODO: use def items, but problem now is that port_items returns term and not array
        items = port_items_from(
          @settings.bondable_interfaces.map(&:name),
          ports,
          Yast::Lan.yast_config # ideally get it from builder?
        )

        # reorder the items
        l1, l2 = items.partition { |t| ports.include? t[0][0] }

        items = l1 + l2.sort_by { |t| justify_dev_name(t[0][0]) }

        Yast::UI.ChangeWidget(:bond_ports_items, :Items, items)

        Yast::UI.ChangeWidget(
          :bond_ports_items,
          :SelectedItems,
          ports
        )

        enable_position_buttons

        nil
      end

      # Default function to store the value of port devices box.
      def store
        @settings.ports = selected_items
      end

      # Validates created bonding. Currently just prevent the user to create a
      # bond with more than one interface sharing the same physical port id
      #
      # @return true if valid or user decision if not
      def validate
        physical_ports = repeated_physical_port_ids(selected_items)

        return false if !physical_ports.empty? && !continue_with_duplicates?(physical_ports)

        if @settings.require_adaptation?(selected_items || [])
          Yast::Popup.ContinueCancel(
            _(
              "At least one selected device is already configured.\n" \
              "Adapt the configuration for bonding?\n"
            )
          )
        elsif @settings.invalid_naming_schema?(selected_items || [])
          return Yast::Popup.ContinueCancel(
            _(
              "At least one selected device is using a MAC address for renaming the device.\n" \
                "Would you like to change the renaming mechanism to BusID?\n"
            )
          )
        end

        true
      end

      def value
        # TODO: it is multiselection, so does it make sense?
        Yast::UI.QueryWidget(:bond_ports_items, :CurrentItem)
      end

      def selected_items
        Yast::UI.QueryWidget(:bond_ports_items, :SelectedItems) || []
      end

      def ui_items
        Yast::UI.QueryWidget(:bond_ports_items, :Items) || []
      end

      def value_index
        ui_items.index { |i| i[0] == Id(value) }
      end

      def enable_position_buttons
        if value_index
          Yast::UI.ChangeWidget(:bond_ports_up, :Enabled, value_index > 0)
          Yast::UI.ChangeWidget(:bond_ports_down, :Enabled, value_index < ui_items.size - 1)
        else
          Yast::UI.ChangeWidget(:bond_ports_up, :Enabled, false)
          Yast::UI.ChangeWidget(:bond_ports_down, :Enabled, false)
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
      # TODO: backend method
      #
      # NOTE: term port is slightly overloaded here. Name of method refers to
      # physical ports of a NIC card (one card can have multiple "plugs" - ports).
      # On the other hand param name refers to pure virtual bonding ports (network
      # devices provided by the system which are virtualy tighted together into a
      # virtual bond device)
      #
      # @param b_ports [Array<String>] bond ports = devices included in the bond
      # @return [Hash{String => Array<String>}]
      #   maps physical ports to non-singleton arrays of bond ports
      def repeated_physical_port_ids(b_ports)
        physical_port_ids = {}

        b_ports.each do |b_port|
          next unless physical_port_id?(b_port)

          p_port = physical_port_id(b_port)
          ps = physical_port_ids[p_port] ||= []
          ps << b_port
        end

        physical_port_ids.select! { |_k, v| v.size > 1 }

        physical_port_ids
      end

      # Given a map of duplicated port ids with device names, aks the user if he
      # would like to continue or not.
      #
      # @param physical_ports [Hash{String => Array<String>}] hash of duplicated physical port ids
      # mapping to an array of device names
      # @return [Boolean] true if continue with duplicates, otherwise false
      def continue_with_duplicates?(physical_ports)
        message = physical_ports.map do |p_port, b_ports|
          wrap_text("PhysicalPortID (#{p_port}): #{b_ports.join(", ")}")
        end.join("\n")

        Yast::Popup.YesNoHeadline(
          Yast::Label.WarningMsg,
          # Translators: Warn the user about not desired effect
          _("The interfaces selected share the same physical port and bonding " \
            "them \nmay not have the desired effect of redundancy.\n\n%s\n\n" \
            "Really continue?\n") % message
        )
      end
    end
  end
end
