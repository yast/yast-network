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

Yast.import "Packages"
Yast.import "SystemdSocket"

module Y2Remote
  class Modes
    class Base
      include Yast::Logger
      include Yast::I18n
      extend Yast::I18n

      class << self
        def to_sym
          name.split("::").last.downcase.to_sym
        end

        def installed?
          Yast::Package.InstalledAll(required_packages)
        end

        def required_packages
          self.const_get("PACKAGES")
        end
      end
    end

    class VNC < Base
      SOCKET = "xvnc".freeze

      class << self
        def required_packages
          Yast::Packages.vnc_packages
        end

        def socket
          Yast::SystemdSocket.find(SOCKET)
        end

        def enabled?
          return false unless socket

          socket.enabled?
        end

        def enable!
          return false unless socket

          socket.enable!
        end

        def disable!
          return false unless socket

          socket.disable!
        end

        def stop!
          return false unless socket

          socket.stop!
        end
      end
    end

    class Manager < Base
      SERVICE  = "vncmanager".freeze
      PACKAGES = ["vncmanager"].freeze

      class << self
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
            Yast::Report.Error(
              Yast::Message.CannotStopService(SERVICE)
            )
          end
        end

        def restart
          return false unless installed?

          Yast::Service.Restart(SERVICE)
        end

        def restart!
          return false unless installed?

          if !Yast::Service.Restart(SERVICE)
            Yast::Report.Error(
              Yast::Message.CannotRestartService(SERVICE)
            )
          end
        end

        def enable!
          return false unless installed?

          if !Yast::Service.Enable(SERVICE)
            Yast::Report.Error(
              _("Enabling service %{service} has failed") % { service: SERVICE}
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

    class Web < Base
      SOCKET   = "xvnc-novnc".freeze
      PACKAGES = ["xorg-x11-Xvnc-novnc"].freeze

      class << self
        def socket
          Yast::SystemdSocket.find(SOCKET)
        end

        def enabled?
          return false unless socket

          socket.enabled?
        end

        def enable!
          return false unless socket

          socket.enable!
        end

        def disable!
          return false unless socket

          socket.disable!
        end

        def stop!
          return false unless socket

          socket.stop!
        end
      end
    end

    MODES = [VNC, Manager, Web].freeze

    def self.all
      MODES
    end

    def self.running_modes
      all.select { |m| m.enabled? }
    end
  end
end
