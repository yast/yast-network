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

require "abstract_method"

module Y2Network
  module Widgets
    # Generic widget for path with browse button
    # TODO: add to CWM as generic widget
    class PathWidget < CWM::CustomWidget
      def initialize
        super()
        textdomain "network"
      end

      abstract_method :label
      abstract_method :browse_label

      def contents
        HBox(
          InputField(Id(text_id), Opt(:hstretch), label),
          VBox(
            VSpacing(1),
            PushButton(Id(button_id), button_label)
          )
        )
      end

      def handle
        directory = File.dirname(value)
        file = ask_method(directory)
        self.value = file if file

        nil
      end

      def value
        Yast::UI.QueryWidget(Id(text_id), :Value)
      end

      def value=(path)
        Yast::UI.ChangeWidget(Id(text_id), :Value, path)
      end

      def text_id
        widget_id + "_path"
      end

      def button_id
        widget_id + "_browse"
      end

      def button_label
        "..."
      end

      # UI method responsible for asking for file/directory. By default uses
      # Yast::UI.AskForExistingFile with "*" filter. Redefine if different popup is needed or
      # specific filter required.
      def ask_method(directory)
        Yast::UI.AskForExistingFile(directory, "*", browse_label)
      end
    end
  end
end
