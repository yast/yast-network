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
require "y2network/dialogs/route"
require "y2network/route"

module Y2Network
  module Widgets
    class AddRoute < CWM::PushButton
      def initialize(table, config)
        @table = table
        @config = config
        textdomain "network"
      end

      def label
        _("Ad&d")
      end

      def handle
        route = Y2Network::Route.new
        res = Y2Network::Dialogs::Route.run(route, @config.interfaces)
        @table.add_route(route) if res == :ok

        nil
      end

      def init
        disable if Yast::NetworkService.network_manager?
      end
    end

    class EditRoute < CWM::PushButton
      def initialize(table, config)
        @table = table
        @config = config
        textdomain "network"
      end

      def label
        _("&Edit")
      end

      def handle
        return nil unless @table.selected_route

        route = @table.selected_route.dup
        res = Y2Network::Dialogs::Route.run(route, @config.interfaces)
        @table.replace_route(route) if res == :ok

        nil
      end

      def init
        disable if Yast::NetworkService.network_manager?
      end
    end

    class DeleteRoute < CWM::PushButton
      def initialize(table)
        @table = table
        textdomain "network"
      end

      def label
        _("De&lete")
      end

      def handle
        return nil unless @table.selected_route

        @table.delete_route

        nil
      end

      def init
        disable if Yast::NetworkService.network_manager?
      end
    end
  end
end
