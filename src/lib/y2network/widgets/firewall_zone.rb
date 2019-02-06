require "cwm"
require "y2firewall/firewalld"
require "y2firewall/helpers/interfaces"
require "y2firewall/firewalld/interface"

module Y2Network
  module Widgets
    class FirewallZone < ::CWM::CustomWidget
      include Y2Firewall::Helpers::Interfaces

      def initialize(name)
        textdomain "network"
        @value = nil
        @interface = Y2Firewall::Firewalld::Interface.new(name)
      end

      def label
        _("Assign Interface to Firewall &Zone")
      end

      def init
        Yast::UI.ChangeWidget(Id(:zones), :Items, firewall_zones)
        self.value = @value
        enable_zones(managed?)
      end

      def contents
        VBox(
          Left(manage_widget),
          Left(zones_widget),
          Left(current_zone_widget)
        )
      end

      def handle(event)
        enable_zones(managed?) if event["ID"] == :manage_zone

        nil
      end

      def value=(name)
        @value = name
        Yast::UI.ChangeWidget(Id(:manage_zone), :Value, !!name)
        return if name.nil?
        select_zone(name)
      end

      def value
        return @value unless Yast::UI.WidgetExists(Id(:manage_zone))

        managed? ? zone : nil
      end

      def store
        @value = value
      end

      def store_zone
        @interface.zone = converted_value if zone_changed?
        @value
      end

    private

      def converted_value
        return "" if @value == ""
        @value
      end

      def zone_changed?
        @value && (current_zone.to_s != converted_value)
      end

      def current_zone_widget
        label = current_zone ? current_zone : _("DEFAULT")

        VBox(
          VSpacing(1),
          Label(_("Current ZONE (permanent config): %s") % label)
        )
      end

      def current_zone
        return unless @interface.zone
        @interface.zone.name
      end

      def manage_widget
        Yast::UI.CheckBox(Id(:manage_zone), Opt(:notify), _("Define Ifcfg ZONE"))
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

      def zone
        Yast::UI.QueryWidget(Id(:zones), :Value)
      end

      def enable_zones(value)
        Yast::UI.ChangeWidget(Id(:zones), :Enabled, value)
      end

      # Return a list of items for ComboBox with all the known firewalld zones
      # and also an empty string option for the default zone.
      #
      # @return [Array <Array <String, String>>] list of names an description of
      # known zones
      def firewall_zones
        zones = [["", _("Default")]]

        if firewalld.installed?
          firewalld.zones.each { |z| zones << [z.name, z.short] }
        else
          zones = [["", _("Firewall is not installed.")]]
        end

        zones.map { |z| Item(Id(z[0]), z[1]) }
      end
    end
  end
end
