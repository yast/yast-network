require "yast"
require "cwm/custom_widget"

Yast.import "UI"

module Y2Network
  module Widgets
    class Tunnel < CWM::CustomWidget
      def initialize(settings)
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
