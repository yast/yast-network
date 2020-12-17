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
        VBox(
          label_widget,
          ip_address_widget,
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

      def focus_label?
        @settings.label.to_s.empty?
      end

      def label_widget
        @label_widget ||= IPAddressLabel.new(@name, @settings, focus: focus_label?)
      end

      def ip_address_widget
        @ip_address_widget ||= Y2Network::Widgets::IPAddress.new(@settings, focus: !focus_label?)
      end

      def netmask_widget
        @netmask_widget ||= Y2Network::Widgets::Netmask.new(@settings)
      end
    end

    # Widget to modify the label of an additional IP address configuration
    class IPAddressLabel < CWM::InputField
      def initialize(name, settings, focus: false)
        textdomain "network"

        @name = name
        @settings = settings
        @focus = focus
      end

      def init
        self.value = @settings.label
        focus if @focus
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
