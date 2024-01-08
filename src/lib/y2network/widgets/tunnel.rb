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

require "yast"
require "cwm/custom_widget"

Yast.import "UI"

module Y2Network
  module Widgets
    class Tunnel < CWM::CustomWidget
      def initialize(settings)
        super()
        textdomain "network"
        @settings = settings
      end

      def contents
        VBox(
          HBox(
            InputField(Id(:tunnel_owner), _("Tunnel owner")),
            InputField(Id(:tunnel_group), _("Tunnel group"))
          )
        )
      end

      def help
        "" # TODO: cannot find it in old helps
      end

      def init
        log.info "init tunnel with #{@settings.inspect}"
        owner, group = @settings.tunnel_user_group

        Yast::UI.ChangeWidget(:tunnel_owner, :Value, owner || "")
        Yast::UI.ChangeWidget(:tunnel_group, :Value, group || "")
      end

      def store
        @settings.assign_tunnel_user_group(
          Yast::UI.QueryWidget(:tunnel_owner, :Value),
          Yast::UI.QueryWidget(:tunnel_group, :Value)
        )
      end
    end
  end
end
