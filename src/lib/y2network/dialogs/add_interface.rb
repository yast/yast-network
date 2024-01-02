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

require "cwm/dialog"
require "y2network/widgets/interface_type"
require "y2network/interface_config_builder"

Yast.import "Label"
Yast.import "Lan"

module Y2Network
  module Dialogs
    # Dialog which starts new device creation
    class AddInterface < CWM::Dialog
      def initialize(default: nil)
        super()
        @type_widget = Widgets::InterfaceType.new(default: default ? default.short_name : nil)

        textdomain "network"
      end

      def title
        # Translators: Dialog headline: adding a configuration of a network interface
        _("Add Interface Configuration")
      end

      def contents
        HVCenter(
          HSquash(
            HBox(
              @type_widget
            )
          )
        )
      end

      # @return [Y2Network::InterfaceConfigBuilder, nil] returns new builder when type selected
      #   or nil if canceled
      def run
        ret = super
        log.info "AddInterface result #{ret}"
        ret = :back if ret == :abort

        return if ret == :back

        # TODO: use factory to get proper builder
        builder = InterfaceConfigBuilder.for(InterfaceType.from_short_name(@type_widget.result))
        proposed_name = Yast::Lan.yast_config.interfaces.free_name(@type_widget.result)
        builder.name = proposed_name

        builder
      end

      # no back button for add dialog
      def back_button
        ""
      end

      # as it is a sub dialog it can only cancel and cannot abort
      def abort_button
        Yast::Label.CancelButton
      end

      # always open new dialog
      def should_open_dialog?
        true
      end
    end
  end
end
