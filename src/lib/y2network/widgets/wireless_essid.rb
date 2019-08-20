require "cwm/common_widgets"
require "cwm/custom_widget"
require "yast2/feedback"

Yast.import "String"

module Y2Network
  module Widgets
    # Widget to setup wifi network essid
    class WirelessEssid < CWM::CustomWidget
      # @param settings [Y2network::InterfaceConfigBuilder]
      def initialize(settings)
        @settings = settings
        textdomain "network"
      end

      def contents
        HBox(
          essid,
          VBox(
            VSpacing(1),
            scan
          )
        )
      end

    private

      def essid
        @essid ||= WirelessEssidName.new(@settings)
      end

      def scan
        @scan ||= WirelessScan.new(@settings, update: essid)
      end
    end

    # Widget for network name combobox
    class WirelessEssidName < CWM::ComboBox
      # @param settings [Y2network::InterfaceConfigBuilder]
      def initialize(settings)
        @settings = settings
        textdomain "network"
      end

      def label
        _("Ne&twork Name (ESSID)")
      end

      def init
        self.value = @settings.essid.to_s
        Yast::UI.ChangeWidget(Id(widget_id), :ValidChars, valid_chars)
      end

      # allow to use not found name e.g. when scan failed or when network is hidden
      def opt
        [:editable]
      end

      # updates essid list with given array and ensure that previously selected value is preserved
      # @param networks [Array<String>]
      def update_essid_list(networks)
        old_value = value
        change_items(networks.map { |n| [n, n] })
        self.value = old_value
      end

    private

      def valid_chars
        Yast::String.CPrint
      end
    end

    # Button for scan network sites
    class WirelessScan < CWM::PushButton
      # @param settings [Y2network::InterfaceConfigBuilder]
      # @param update [WirelessEssidName]
      def initialize(settings, update:)
        @settings = settings
        @update_widget = update
        textdomain "network"
      end

      def label
        _("Scan Network")
      end

      def handle
        networks = essid_list

        Yast2::Feedback.show("Obtaining essid list", headline: "Scanning network") do |_f|
          networks = essid_list
          log.info("Found networks: #{networks}")
        end

        return unless @update_widget
        @update_widget.update_essid_list(networks)
        nil
      end

    private

      def obtained_networks(networks)
        output = "<ul>"
        networks.map { |n| output << "<li>#{n}</li>" }
        output << "</ul>"
        output
      end

      def essid_list
        command = "#{link_up} && #{scan} | #{grep_and_cut_essid} | #{sort}"

        output = Yast::SCR.Execute(Yast::Path.new(".target.bash_output"), command)
        output["stdout"].split("\n")
      end

      def sort
        "/usr/bin/sort -u"
      end

      def grep_and_cut_essid
        "/usr/bin/grep ESSID | /usr/bin/cut -d':' -f2 | /usr/bin/cut -d'\"' -f2"
      end

      def link_up
        "/usr/sbin/ip link set #{interface} up"
      end

      def scan
        "/usr/sbin/iwlist #{interface} scan"
      end

      def interface
        @settings.name
      end
    end
  end
end
