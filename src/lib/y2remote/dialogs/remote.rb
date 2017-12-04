# encoding: utf-8

# ------------------------------------------------------------------------------
# Copyright (c) 2017 SUSE LLC
#
#
# This program is free software; you can redistribute it and/or modify it under
# the terms of version 2 of the GNU General Public License as published by the
# Free Software Foundation.
#
# This program is distributed in the hope that it will be useful, but WITHOUT
# ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS
# FOR A PARTICULAR PURPOSE. See the GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License along with
# this program; if not, contact SUSE.
#
# To contact SUSE about this file by physical or electronic mail, you may find
# current contact information at www.suse.com.
# ------------------------------------------------------------------------------

require "yast"
require "cwm/dialog"
require "y2remote/widgets/remote"

module Y2Remote
  module Dialogs
    class Remote < CWM::Dialog
      def title
        _("Remote Administration")
      end

      def contents
        HBox(
          HStretch(),
          VBox(
            Frame(
              # Dialog frame title
              _("Remote Administration Settings"),
              Widgets::RemoteSettings.new
            ),
            VSpacing(1),
            Widgets::RemoteFirewall.new
          ),
          HStretch()
        )
      end

    private

      def should_open_dialog?
        true
      end
    end
  end
end
