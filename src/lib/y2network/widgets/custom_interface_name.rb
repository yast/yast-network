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
require "cwm/common_widgets"

Yast.import "Popup"

module Y2Network
  module Widgets
    class CustomInterfaceName < CWM::InputField
      # Constructor
      #
      # @param builder [InterfaceConfigBuilder] Interface configuration builder object
      def initialize(builder)
        textdomain "network"
        @builder = builder
        @old_name = builder.name
      end

      # @see CWM::AbstractWidget#label
      def label
        _("Device Name")
      end

      # @see CWM::AbstractWidget#opt
      def opt
        [:hstretch]
      end

      # @see CWM::AbstractWidget#init
      def init
        self.value = @builder.name
      end

      # Saves the current value so it can be queried after the widget is closed
      # @see CWM::AbstractWidget#init
      def store
        @value = value
      end

      # Current value
      #
      # @return [String,nil]
      def value
        @value || super
      end

      # The value is valid when it does not contain unexpected characters
      # and it is not taken already.
      #
      # @return [Boolean]
      #
      # @see CWM::AbstractWidget#opt
      # @see Y2Network::InterfaceConfigBuilder#name_exists?
      # @see Y2Network::InterfaceConfigBuilder#valid_name?
      def validate
        if @old_name != value && @builder.name_exists?(value)
          Yast::Popup.Error(_("Configuration name already exists."))
          return false
        end

        if !@builder.valid_name?(value)
          Yast::Popup.Error(_("Invalid configuration name."))
          return false
        end

        true
      end
    end
  end
end
