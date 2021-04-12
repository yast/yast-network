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

require "cwm/common_widgets"
require "cwm/custom_widget"

module Y2Network
  module Widgets
    # Widget for setting the Lcs group device lancmd timeout
    class S390LanCmdTimeout < CWM::InputField
      # Constructor
      #
      # @param settings [Y2Network::InterfaceConfigBuilder]
      def initialize(settings)
        textdomain "network"

        @settings = settings
      end

      # @see CWM::AbstractWidget
      def label
        _("&LANCMD Time-Out")
      end

      # @see CWM::AbstractWidget
      def init
        self.value = @settings.timeout
      end

      # @see CWM::AbstractWidget
      def store
        @settings.timeout = value
      end

      # @see CWM::AbstractWidget
      def help
        _("<p>Specify the <b>LANCMD Time-Out</b> for this interface.</p>")
      end
    end

    # Widget for setting the Ctc device protocol to be used
    class S390Protocol < CWM::ComboBox
      # Constructor
      #
      # @param settings [Y2Network::InterfaceConfigBuilder]
      def initialize(settings)
        textdomain "network"

        @settings = settings
      end

      # @see CWM::AbstractWidget
      def init
        self.value = @settings.protocol.to_s
      end

      # @see CWM::AbstractWidget
      def label
        _("&Protocol")
      end

      # @see CWM::AbstractWidget
      def items
        [
          # ComboBox item: CTC device protocol
          ["0", _("Compatibility Mode")],
          # ComboBox item: CTC device protocol
          ["1", _("Extended Mode")],
          # ComboBox item: CTC device protocol
          ["2", _("CTC-Based tty (Linux to Linux Connections)")],
          # ComboBox item: CTC device protocol
          ["3", _("Compatibility Mode with OS/390 and z/OS")]
        ]
      end

      # @see CWM::AbstractWidget
      def store
        @settings.protocol = value.to_i
      end

      # @see CWM::AbstractWidget
      def help
        _("<p>Choose the <b>Protocol</b> for this interface.</p>")
      end
    end

    # Widget for specifying whether use the port number 0 or 1
    class S390PortNumber < CWM::ComboBox
      # Constructor
      #
      # @param settings [Y2Network::InterfaceConfigBuilder]
      def initialize(settings)
        textdomain "network"

        @settings = settings
      end

      # @see CWM::AbstractWidget
      def init
        self.value = @settings.port_number.to_s
      end

      # @see CWM::AbstractWidget
      def label
        _("Port Number")
      end

      # @see CWM::AbstractWidget
      def items
        [["0", "0"], ["1", "1"]]
      end

      # @see CWM::AbstractWidget
      def store
        @settings.port_number = value.to_i
      end

      # @see CWM::AbstractWidget
      def help
        _("<p>Choose which physical <b>Port Number</b> on the OSA Adapter " \
          "will be used by this interface. <b>(0 by default)</b></p>")
      end
    end

    # This widget permits to pass defined any extra attribute to set during
    # Qeth device activation
    class S390Attributes < CWM::InputField
      # Constructor
      #
      # @param settings [Y2Network::InterfaceConfigBuilder]
      def initialize(settings)
        textdomain "network"
        @settings = settings
      end

      # @see CWM::AbstractWidget
      def label
        _("Options")
      end

      # @see CWM::AbstractWidget
      def init
        self.value = @settings.attributes
      end

      # @see CWM::AbstractWidget
      def opt
        [:hstretch]
      end

      # @see CWM::AbstractWidget
      def help
        # TRANSLATORS: S/390 dialog help for QETH Options
        _("<p>Enter any additional <b>Options</b> for this interface (separated by spaces).</p>")
      end

      # @see CWM::AbstractWidget
      def store
        @settings.attributes = value
      end
    end

    # Checkbox for enabling IPA Takeover in the configured interface
    class S390IPAddressTakeover < CWM::CheckBox
      # Constructor
      #
      # @param settings [Y2Network::InterfaceConfigBuilder]
      def initialize(settings)
        textdomain "network"
        @settings = settings
      end

      # @see CWM::AbstractWidget
      def init
        self.value = !!@settings.ipa_takeover
      end

      # @see CWM::AbstractWidget
      def label
        _("Enable IPA takeover")
      end

      # @see CWM::AbstractWidget
      def help
        _("<p>Select <b>Enable IPA Takeover</b> if IP address takeover should be enabled " \
          "for this interface.</p>")
      end

      # @see CWM::AbstractWidget
      def store
        @settings.ipa_takeover = value
      end
    end

    # This custom widget contents a checkbox for enabling the layer2 support
    # and an input field for setting the mac address to be used in case of
    # enablement.
    class S390Layer2 < CWM::CustomWidget
      # Constructor
      #
      # @param settings [Y2Network::InterfaceConfigBuilder]
      def initialize(settings)
        textdomain "network"
        @settings = settings
        self.handle_all_events = true
      end

      # @see CWM::AbstractWidget
      def contents
        VBox(
          Left(support_widget),
          Left(mac_address_widget)
        )
      end

      # @see CWM::AbstractWidget
      def init
        refresh
      end

      # @see CWM::AbstractWidget
      def handle(event)
        case event["ID"]
        when support_widget.widget_id
          refresh
        end

        nil
      end

      # @see CWM::AbstractWidget
      def validate
        return true if !layer2? || valid_mac?(mac_address_widget.value)

        report_mac_error
        false
      end

      # @see CWM::AbstractWidget
      def store
        @settings.layer2 = layer2?
        @settings.lladdress = layer2? ? lladdress_for(mac_address_widget.value) : nil
      end

    private

      def report_mac_error
        # TRANSLATORS: Popup error about not valid MAC address provided
        msg = _("The MAC address provided is not valid, please provide a valid one.")
        Yast::Popup.Error(msg)
      end

      # Convenience method to check whether layer2 support is enabled or not
      #
      # @return [Boolean] true if enabled; false otherwise
      def layer2?
        !!support_widget.value
      end

      # Convenience method to check whether the MAC address provided is valid
      # or not
      #
      # @return [Boolean] true when valid; false otherwise
      # @param mac_address [String]
      def valid_mac?(mac_address)
        return true unless lladdress_for(mac_address)

        !!(mac_address =~ /^([0-9a-fA-F]{2}[:-]){5}[0-9a-fA-F]{2}$/i)
      end

      # Return the MAC address in case it is not empty or a zero's MAC address
      # otherwise it returns nil.
      #
      # @param mac_widget_value [String]
      # @return [String, nil] the MAC address in case it is not empty or a
      #   zero's MAC address; nil otherwise
      def lladdress_for(mac_widget_value)
        return if ["", "00:00:00:00:00:00"].include?(mac_widget_value.to_s)

        mac_widget_value
      end

      # Convenience method to enable or disable the mac address widget when the
      # layer2 support is modified
      def refresh
        support_widget.checked? ? mac_address_widget.enable : mac_address_widget.disable
      end

      # @return [S390Layer2Support]
      def support_widget
        @support_widget ||= S390Layer2Support.new(@settings)
      end

      # @return [S390Layer2Address]
      def mac_address_widget
        @mac_address_widget ||= S390Layer2Address.new(@settings)
      end
    end

    # Widget for enabling layer2 support in the configured device
    class S390Layer2Support < CWM::CheckBox
      # Constructor
      #
      # @param settings [Y2Network::InterfaceConfigBuilder]
      def initialize(settings)
        textdomain "network"
        @settings = settings
      end

      # @see CWM::AbstractWidget
      def init
        self.value = !!@settings.layer2
      end

      # @see CWM::AbstractWidget
      def opt
        # Needed for handling the event in other widgets that contents it.
        [:notify]
      end

      # @see CWM::AbstractWidget
      def label
        _("Enable Layer2 Support")
      end

      # @see CWM::AbstractWidget
      def help
        "<p>Select <b>Enable Layer 2 Support</b> if this card has been " \
         "configured with layer 2 support.</p>"
      end
    end

    # Widget for setting the mac address to be used in case of layer2 supported
    class S390Layer2Address < CWM::InputField
      # Constructor
      #
      # @param settings [Y2Network::InterfaceConfigBuilder]
      def initialize(settings)
        textdomain "network"
        @settings = settings
      end

      # @see CWM::AbstractWidget
      def init
        self.value = @settings.lladdress
      end

      # @see CWM::AbstractWidget
      def label
        _("Layer2 MAC Address")
      end

      # @see CWM::AbstractWidget
      def help
        _("<p>Enter the <b>Layer 2 MAC Address</b> if this card has been " \
          "configured with layer 2 support <b>(optional)</b>.</p>")
      end
    end
  end
end
