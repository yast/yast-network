# encoding: utf-8
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
      # @param name [String]
      def initialize(name)
        textdomain "network"
        @value = nil
        @interface = Y2Firewall::Firewalld::Interface.new(name)
      end

      # @see CWM::AbstractWidget
      # @return [String]
      def label
        _("Assign Interface to Firewall &Zone")
      end

      # @see CWM::AbstractWidget
      def init
        return unless installed?

        populate_select(firewall_zones)
        self.value = @value
        enable_zones(managed?)
      end

      # @see CWM::AbstractWidget
      def contents
        return Label(_("Firewall is not installed.")) unless installed?

        VBox(
          Left(manage_widget),
          Left(zones_widget),
          Left(permanent_config_widget)
        )
      end

      # @see CWM::AbstractWidget
      # @param event [Hash]
      def handle(event)
        enable_zones(managed?) if event["ID"] == :manage_zone

        nil
      end

      # Stores the given name and when it is enabled to configure the
      # interface ZONE through the ifcfg file. It also selects the given zone
      # in the select list
      #
      # @see CWM::AbstractWidget
      # @param name [String,nil] zone name
      def value=(name)
        @value = name
        return unless installed?
        manage_zone!(!!name) && select_zone(name)
      end

      # It returns the current ZONE selection or nil in case of not enabled
      # the management through the ifcfg files.
      #
      # @return [String, nil] current zone or nil when not managed
      def value
        return @value unless Yast::UI.WidgetExists(Id(:manage_zone))

        managed? ? selected_zone : nil
      end

      # Stores the current value
      #
      # @see CWM::AbstractWidget
      # @return [String, nil]
      def store
        @value = value
      end

      # Stores the selected zone permanently when it has change and it is
      # enabled to be managed through the ifcfg files
      #
      # @return [String, nil] the current zone selection
      def store_zone
        return @value unless installed?

        @interface.zone = @value if zone_changed?
        @value
      end

      # @see CWM::AbstractWidget
      def help
        help_text =
          _("<p><b><big>FIREWALL ZONE</big></b></p>" \
            "<p>A network zone defines the level of trust for network connections. " \
            "The <b>ZONE</b> can be set by yast-firewall, by different firewalld " \
            "utilities or via the ifcfg file.</p>" \
            "<p>When enabled in yast-network, it sets the <b>ZONE</b> which this " \
            "interface belongs to modifying also the firewalld permanent " \
            "configuration</p>")

        help_text << zones_help if installed?
        help_text
      end

    private

      # Return whether the permanent ZONE match or not the selected one.
      #
      # @return [Boolean]
      def zone_changed?
        @value && (current_zone.to_s != @value)
      end

      def default_label
        _("DEFAULT")
      end

      def permanent_config_widget
        label = current_zone ? current_zone : default_label

        VBox(
          VSpacing(1),
          Label(_("Current ZONE (permanent config): %s") % label),
          Label(_("Default ZONE (permanent config): %s") % firewalld.default_zone)
        )
      end

      def current_zone
        return unless @interface.zone
        @interface.zone.name
      end

      def manage_widget
        CheckBox(Id(:manage_zone), Opt(:notify), _("Define Ifcfg ZONE"))
      end

      def manage_zone!(value)
        Yast::UI.ChangeWidget(Id(:manage_zone), :Value, value)
        value
      end

      def managed?
        Yast::UI.QueryWidget(Id(:manage_zone), :Value)
      end

      def zones_widget
        ComboBox(Id(:zones), Opt(:notify, :hstretch), _("ZONE"))
      end

      def select_zone(zone)
        Yast::UI.ChangeWidget(Id(:zones), :Value, zone)
      end

      def selected_zone
        Yast::UI.QueryWidget(Id(:zones), :Value)
      end

      def enable_zones(value)
        Yast::UI.ChangeWidget(Id(:zones), :Enabled, value)
      end

      def populate_select(zones)
        items = zones.map { |z| Item(Id(z[0]), z[1]) }
        Yast::UI.ChangeWidget(Id(:zones), :Items, items)
      end

      # Return a list of items for ComboBox with all the known firewalld zones
      # and also an empty string option for the default zone.
      #
      # @return [Array <Array <String, String>>] list of names an description of
      # known zones
      def firewall_zones
        zones = [["", default_label]]
        firewalld.zones.each { |z| zones << [z.name, z.short] }
        zones
      end

      def installed?
        @installed ||= firewalld.installed?
      end

      def zones_help
        description = firewalld.zones.map { |z| zone_description(z) }
        return "" if description.empty?

        _("<p>Find below the available zones description: <ul>%s</ul></p>") % description.join
      end

      def zone_description(zone)
        "<li><b>#{zone.short}: </b>" \
        "#{zone.description} " \
        "(Masquerade: #{zone.masquerade? ? "yes" : "no"})" \
        "</li>"
      end
    end
  end
end
