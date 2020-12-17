# Copyright (c) [2020] SUSE LLC
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
require "y2network/ip_address"
require "y2network/widgets/ip_address"
require "y2network/widgets/netmask"

module Y2Network
  module Dialogs
    # Popup dialog to add or edit an additional IP address configuration to a
    # connection config
    class AdditionalAddress < CWM::Popup
      # Constructor
      #
      # @param name [String]
      # @param settings [Object]
      def initialize(name, settings)
        textdomain "network"

        @name     = name
        @settings = settings
      end

      def contents
        focus_label = @settings.label.to_s.empty?

        VBox(
          label_widget(focus_label),
          ip_address_widget(!focus_label),
          netmask_widget
        )
      end

      def run
        ret = super
        return ret if ret != :ok || @settings.subnet_prefix.start_with?("/")

        netmask = @settings.subnet_prefix
        prefix = IPAddr.new("#{netmask}/#{netmask}").prefix
        @settings.subnet_prefix = "/#{prefix}"

        ret
      end

    private

      def buttons
        [ok_button, cancel_button]
      end

      def label_widget(focus)
        @label_widget ||= IPAddressLabel.new(@name, @settings)
        @label_widget.focus if focus
        @label_widget
      end

      def ip_address_widget(focus)
        @ip_address_widget ||= Y2Network::Widgets::IPAddress.new(@settings)
        @ip_address_widget if focus
        @ip_address_widget
      end

      def netmask_widget
        @netmask_widget ||= Y2Network::Widgets::Netmask.new(@settings)
      end
    end

    # Widget to modify the label of an additional IP address configuration
    class IPAddressLabel < CWM::InputField
      def initialize(name, settings)
        textdomain "network"

        @name = name
        @settings = settings
      end

      def init
        self.value = @settings.label
        Yast::UI.ChangeWidget(Id(widget_id), :ValidChars, Yast::String.CAlnum)
      end

      def label
        _("&Address Label")
      end

      def store
        @settings.label = value
      end

      def validate
        return true if "#{@name}.#{value}" =~ /^[[:alnum:]._:-]{1,15}\z/

        Yast::Popup.Error(_("Label is too long."))
        focus
        false
      end
    end
  end
end
