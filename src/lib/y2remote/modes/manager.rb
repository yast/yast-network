require "y2remote/modes/base"

module Y2Remote
  module Modes
    class Manager < Base
      SERVICE  = "vncmanager".freeze
      PACKAGES = ["vncmanager"].freeze

      def required_packages
        PACKAGES
      end

      def enabled?
        Yast::Service.Enabled(SERVICE)
      end

      def stop
        return false unless installed?

        Yast::Service.Stop(SERVICE)
      end

      def stop!
        return false unless installed?

        if !Yast::Service.Stop(SERVICE)
          Yast::Report.Error(Yast::Message.CannotStopService(SERVICE))
          return false
        end

        true
      end

      def restart
        return false unless installed?

        Yast::Service.Restart(SERVICE)
      end

      def restart!
        return false unless installed?

        if !Yast::Service.Restart(SERVICE)
          Yast::Report.Error(Yast::Message.CannotRestartService(SERVICE))
          return false
        end

        true
      end

      def enable!
        return false unless installed?

        if !Yast::Service.Enable(SERVICE)
          Yast::Report.Error(
            _("Enabling service %{service} has failed") % { service: SERVICE }
          )
          return false
        end

        true
      end

      def disable!
        return false unless installed?

        if !Yast::Service.Disable(SERVICE)
          Yast::Report.Error(
            _("Disabling service %{service} has failed") % { service: SERVICE }
          )
          return false
        end

        true
      end
    end
  end
end
