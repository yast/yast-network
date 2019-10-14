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

module Y2Remote
  # Class responsable of handle the display manager configuration for remote
  # access.
  class DisplayManager
    include Singleton
    include Yast::I18n
    include Yast::Logger

    # Display manager service name
    SERVICE = "display-manager".freeze

    # Constructor
    def initialize
      Yast.import "Service"
      textdomain "network"
    end

    # Whether the display manager service is enabled or not
    #
    # @return [Boolean] true if enabled; false otherwise
    def enabled?
      Yast::Service.Enabled(SERVICE)
    end

    # Whether the display manager allow remote access or not. If the service is
    # not enabled it returns false
    #
    # @return [Boolean] true if allowed and service is enabled
    def remote_access?
      return false unless enabled?

      Yast::SCR.Read(Yast.path(".sysconfig.displaymanager.DISPLAYMANAGER_REMOTE_ACCESS")) == "yes"
    end

    # Restart the display manager service reporting an error in case of
    # failure.
    def restart
      if Yast::Service.active?(SERVICE)
        report_cannot_restart(SERVICE) if !Yast::Service.Reload(SERVICE)

        Yast::Report.Warning(
          _(
            "Your display manager must be restarted.\n" \
            "To take the changes in remote administration into account, \n" \
            "please restart it manually or log out and log in again."
          )
        )
      elsif !Yast::Service.Restart(SERVICE)
        report_cannot_restart(SERVICE)
      end
    end

    # Write the sysconfig display manager configuration for remote access.
    #
    # @param allowed [Boolean] whether the remote access is allowed or not
    def write_remote_access(allowed)
      # Set DISPLAYMANAGER_REMOTE_ACCESS in sysconfig/displaymanager
      Yast::SCR.Write(
        Yast.path(".sysconfig.displaymanager.DISPLAYMANAGER_REMOTE_ACCESS"),
        allowed ? "yes" : "no"
      )
      Yast::SCR.Write(
        Yast.path(".sysconfig.displaymanager.DISPLAYMANAGER_ROOT_LOGIN_REMOTE"),
        allowed ? "yes" : "no"
      )
      Yast::SCR.Write(Yast.path(".sysconfig.displaymanager"), nil)

      true
    end

  private

    # Convenience method to report a not able to restart service error message.
    #
    # @param service_name [String] servie name to report about
    def report_cannot_restart(service_name)
      Yast::Report.Error(Yast::Message.CannotRestartService(service_name))
    end
  end
end
