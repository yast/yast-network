# Copyright (c) [2025] SUSE LLC
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

require "cwm/popup"
require "cwm/common_widgets"
require "y2network/widgets/renaming_mechanism"

module Y2Network
  module Dialogs
    # RichText with the config summary of the given bonds mainly focused in
    # the ports naming mechanism
    class BondingConfigSummary < CWM::RichText
      include Presenters::InterfaceStatus
      attr_reader :config
      attr_reader :bonds

      def initialize(config, bonds)
        textdomain "network"

        @config = config
        @bonds = bonds
      end

      def init
        self.value = summary
      end

    private

      def summary
        bonds.map { |b| bond_summary(b) }.join("<br>")
      end

      def port_summary(port)
        interface = config.interfaces.by_name(port)
        hardware = interface.hardware
        text = "<b>" + port + "<b><br>"

        if hardware.nil? || !hardware.exists?
          text << "<b>" << _("No hardware information") << "</b><br>"
        else
          text << "<b>MAC : </b>" << hardware.mac << "<br>" if hardware.mac
          text << "<b>BusID : </b>" << hardware.busid << "<br>" if hardware.busid
          mechanism =
            case interface&.renaming_mechanism
            when :mac
              "MAC"
            when :bus_id
              "BusID"
            else
              "None"
            end
          text << "<b>Renaming mechanism : </b>" << mechanism
        end

        text
      end

      def bond_summary(conn)
        rich = "<b>" + _("Bond Name: %s") % conn.name + "</b><br>"
        rich << "<b>" + _("Bond Ports") + "</b><br>"
        rich << Yast::HTML.List(conn.ports.map { |p| port_summary(p) })
        rich
      end
    end

    # This widget allows to modify all the udev rules of the bond members using
    # the bus_id instead of the mac address as the device matching key
    class BondingFix < CWM::Popup
      attr_reader :interface
      attr_reader :config

      # Constructor
      #
      # @param config [Y2Network::Config]
      def initialize(config)
        require "y2network/presenters/interface_summary"
        textdomain "network"

        @config = config
      end

      # @see CWM::AbstractWidget
      def title
        _("Bond ports using MAC address")
      end

      # @see CWM::CustomWidget
      def contents
        HBox(
          HSpacing(0.5),
          VBox(
            Label(intro),
            MinSize(55, 14, bond_description),
            Label(question)
          ),
          HSpacing(0.5)
        )
      end

      def run
        ret = super
        apply_renaming if ret == :ok
        ret
      end

      def needs_to_be_run?
        !invalid_bonds.empty?
      end

    private

      def iface_for(port)
        config.interfaces.by_name(port)
      end

      def invalid_bonds
        @config.connections.select do |conn|
          conn.is_a?(Y2Network::ConnectionConfig::Bonding) &&
            conn.ports.any? { |p| iface_for(p)&.renaming_mechanism == :mac }
        end
      end

      def apply_renaming
        invalid_bonds.each do |bond|
          bond.ports.each do |port|
            interface = iface_for(port)
            interface&.rename(interface.name, :bus_id) if interface&.renaming_mechanism == :mac
          end
        end
        Yast::Lan.SetModified
      end

      def intro
        _("There are some bond ports using an udev rule based on MAC address for renaming\n" \
          "the device which is not recommended and could cause some naming problem.")
      end

      def bond_description
        @bond_description ||= BondingConfigSummary.new(config, invalid_bonds)
      end

      def question
        _("Would you like to change the bond ports renaming mechanism to BusID?")
      end

      def ok_button_label
        Yast::Label.YesButton
      end

      def cancel_button_label
        Yast::Label.NoButton
      end

      # Returns the dialogs button
      #
      # @return [Array<Yast::Term>]
      def buttons
        [ok_button, cancel_button]
      end
    end
  end
end
