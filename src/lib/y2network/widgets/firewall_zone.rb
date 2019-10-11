#
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

require "cwm"
require "y2firewall/firewalld"
require "y2firewall/helpers/interfaces"
require "y2firewall/firewalld/interface"

module Y2Network
  module Widgets
    # This widget offers a checkbox for enabling the firewalld interface ZONE
    # mapping through the ifcfg file and a selection list for choose the ZONE
    # to be used.
    class FirewallZone < ::CWM::CustomWidget
      include Y2Firewall::Helpers::Interfaces

      # Constructor
      #
      # @param builder [Y2Network::InterfaceConfigBuilder]
      def initialize(builder)
        textdomain "network"
        @builder = builder
        @interface = Y2Firewall::Firewalld::Interface.new(builder.name)
      end

      # @see CWM::AbstractWidget
      # @return [String]
      def label
        # TRANSLATORS: label for Firewall ZONE assignment
        _("Assign Interface to Firewall &Zone")
      end

      # @see CWM::AbstractWidget
      def init
        return unless installed?

        populate_select(firewall_zones)
        select_zone(@builder.firewall_zone) if installed?
      end

      # @see CWM::AbstractWidget
      def contents
        # TRANSLATORS: firewall is not installed label
        return Label(_("Firewall is not installed.")) unless installed?

        Left(zones_widget)
      end

      # It returns the current ZONE selection or nil in case of not enabled
      # the management through the ifcfg files.
      #
      # @return [String, nil] current zone or nil when not managed
      def value
        selected_zone
      end

      # Stores the current value
      #
      # @see CWM::AbstractWidget
      # @return [String, nil]
      def store
        @builder.firewall_zone = value
      end

      # @see CWM::AbstractWidget
      def help
        help_text =
          # TRANSLATORS: Firewall ZONE widget help description
          _("<p><b><big>FIREWALL ZONE</big></b></p>" \
            "<p>A network zone defines the level of trust for network connections. " \
            "The selected ZONE will be added to the ifcfg as well as the firewalld " \
            "permanent configuration.</p>")

        help_text += zones_help if installed?
        help_text
      end

    private

      # @return [String]
      def default_label
        # TRANSLATORS: List item describing an assigment of the interface
        # to the default ZONE
        _("Assign to the default ZONE")
      end

      # @return [Yast::Term] zones select list
      def zones_widget
        ComboBox(Id(:zones), Opt(:notify, :hstretch), label)
      end

      # Convenince method to select an specific zone from the zones list
      #
      # @param zone [String]
      def select_zone(zone)
        Yast::UI.ChangeWidget(Id(:zones), :Value, zone)
      end

      # Convenince method which returns the selected zone from the zones list
      #
      # @return [String, nil]
      def selected_zone
        Yast::UI.QueryWidget(Id(:zones), :Value)
      end

      # @param zones [Array <Array <String, String>>] list of available zones
      # names
      def populate_select(zones)
        items = zones.map { |z| Item(Id(z[0]), z[1]) }
        Yast::UI.ChangeWidget(Id(:zones), :Items, items)
      end

      # Return a list of items for ComboBox with all the known firewalld zones
      # and also an empty string option for the default zone.
      #
      # @return [Array <Array <String, String>>] list of names an description of
      # available zones
      def firewall_zones
        zones = [["", default_label]]
        firewalld.zones.each { |z| zones << [z.name, z.name] }
        zones
      end

      # Convenience method to check whether firewalld is installed or not
      #
      # @return [Boolean] whether firewalld is installed or not
      def installed?
        @installed ||= firewalld.installed?
      end

      # Help text with the description of the available zones
      #
      # @return [String] zones help description
      def zones_help
        description = firewalld.zones.map { |z| zone_description(z) }
        return "" if description.empty?

        # TRANSLATORS: Firewall zones description (%s are list element with
        # each of the zones decription)
        _("<p>Find below the available zones description: <ul>%s</ul></p>") % description.join
      end

      # Return the description of the given zone as a HTML list entry
      #
      # @param zone [Y2Firewall::Firewalld::Zone]
      # @return [String] zone description
      def zone_description(zone)
        "<li><b>#{zone.short}: </b>" \
        "#{zone.description} " \
        "(Masquerade: #{zone.masquerade? ? "yes" : "no"})" \
        "</li>"
      end
    end
  end
end
