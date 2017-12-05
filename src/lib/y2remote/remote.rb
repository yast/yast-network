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
require "y2remote/modes"

module Y2Remote
  class Remote
    include Singleton
    include Yast::Logger
    include Yast::I18n

    XDM_SERVICE_NAME = "display-manager".freeze
    GRAPHICAL_TARGET = "graphical".freeze

    FIREWALL_SERVICES_PACKAGE = "xorg-x11-Xvnc".freeze

    # [Symbol] Remote administration mode, :disabled, :xvnc or :vncmanager
    attr_reader :modes

    attr_accessor :proposed

    alias_method :proposed?, :proposed

    def initialize
      import_modules

      textdomain "network"

      @modes = []
      @proposed = false
    end

    # Checks if remote administration is currently allowed
    def enabled?
      !disabled?
    end

    def enable!
      enable_mode!(Y2Remote::Modes::VNC.instance)
    end

    def enable_manager!
      enable_mode!(Y2Remote::Modes::Manager.instance)
    end

    def enable_web!
      enable_mode!(Y2Remote::Modes::Web.instance)
    end

    # Checks if remote administration is currently disallowed
    def disabled?
      modes.empty?
    end

    # Removes all the running modes
    #
    # @return [Array<Y2Remote::Mode>]
    def disable!
      @modes = []
    end

    # Whether some of the VNC running modes is Web or not
    #
    # @return [Boolean] true if web is enabled; false otherwise
    def web_enabled?
      modes.include?(Y2Remote::Modes::Web.instance)
    end

    # Whether the vnc manager mode is enabled or not
    #
    # @return [Boolean] true it the :manager mode is enabled
    def with_manager?
      modes.include?(Y2Remote::Modes::Manager.instance)
    end

    # Read the current status of vnc and the enabled modes
    #
    # @return [Boolean] true
    def read
      return true unless xdm_enabled? && display_manager_remote_access?

      @modes = Y2Remote::Modes.running_modes

      true
    end

    # Update the SCR according to vnc settings
    #
    # @return [Boolean] true on success
    def write
      steps = [_("Configure display manager")]
      steps << _("Restart the services") if Yast::Mode.normal

      caption = _("Saving Remote Administration Configuration")

      Yast::Progress.New(caption, " ", steps.size, steps, [], "")
      Yast::Progress.NextStage
      Yast::Progress.Title(_("Configuring display manager..."))
      return false unless configure_display_manager

      if Yast::Mode.normal
        Yast::Progress.NextStage
        Yast::Progress.Title(_("Restarting the service..."))
        restart_services
        Yast::Progress.NextStage
      end

      true
    end

    # Reset the proposal configuration enabling vnc if it was enabled by
    # linuxrc
    def reset!
      @proposed = false

      propose!
    end

    # It propose the vnc configuration if it has not been proposed yet
    #
    # @return [Boolean]
    def propose!
      return false if proposed?

      Yast::Linuxrc.vnc ? enable_vnc! : disable!

      log.info("Remote Administration was proposed as: #{modes.inspect}")

      @proposed = true
    end

    # Updates the VNC and xdm configuration
    #
    # Called from #write. Ensures that required packages are installed,
    # enables vnc services and xdm and writes the configuration files,
    # reporting any error in the process.
    #
    # @return [Boolean] true if success, false otherwise
    def configure_display_manager
      if enabled?
        # Install required packages
        if !Yast::Package.InstallAll(required_packages)
          log.error "Installing of required packages failed"
          return false
        end

        Y2Remote::Modes.update_status(modes)
      end

      # Set DISPLAYMANAGER_REMOTE_ACCESS in sysconfig/displaymanager
      Yast::SCR.Write(
        Yast.path(".sysconfig.displaymanager.DISPLAYMANAGER_REMOTE_ACCESS"),
        enabled? ? "yes" : "no"
      )
      Yast::SCR.Write(
        Yast.path(".sysconfig.displaymanager.DISPLAYMANAGER_ROOT_LOGIN_REMOTE"),
        enabled? ? "yes" : "no"
      )
      Yast::SCR.Write(Yast.path(".sysconfig.displaymanager"), nil)

      true
    end

    def restart_display_manager
      if Yast::Service.active?(XDM_SERVICE_NAME)
        Yast::Report.Error(
          Yast::Message.CannotRestartService(XDM_SERVICE_NAME)
        ) if !Yast::Service.Reload(XDM_SERVICE_NAME)

        Yast::Report.Warning(
          _(
            "Your display manager must be restarted.\n" \
            "To take the changes in remote administration into account, \n" \
            "please restart it manually or log out and log in again."
          )
        )
      elsif !Yast::Service.Restart(XDM_SERVICE_NAME)
        Yast::Report.Error(
          Yast::Message.CannotRestartService(XDM_SERVICE_NAME)
        )
      end
    end

    # Restarts services, reporting errors to the user
    def restart_services
      Yast::SystemdTarget.set_default(GRAPHICAL_TARGET) if enabled?

      Y2Remote::Modes.restart_modes

      restart_display_manager if enabled?
    end

    def summary
      return _("Remote administration is enabled.") if enabled?

      _("Remote administration is disabled.")
    end

  private

    def import_modules
      Yast.import "Mode"
      Yast.import "Package"
      Yast.import "Packages"
      Yast.import "Service"
      Yast.import "SuSEFirewall"
      Yast.import "Progress"
      Yast.import "Linuxrc"
      Yast.import "Message"
      Yast.import "SystemdTarget"
    end

    # Obtains a list of the required packages for the enabled vnc modes
    def required_packages
      modes.map(&:required_packages).flatten
    end

    def display_manager_remote_access?
      Yast::SCR.Read(Yast.path(".sysconfig.displaymanager.DISPLAYMANAGER_REMOTE_ACCESS")) == "yes"
    end

    def xdm_enabled?
      Yast::Service.Enabled(XDM_SERVICE_NAME)
    end

    # Adds the given mode to the list of modes to be enabled
    #
    # @return [Array<Symbol>] list of enable vnc modes
    def enable_mode!(mode)
      return modes if modes.include?(mode)

      case mode
      when Y2Remote::Modes::VNC.instance
        @modes.delete(Y2Remote::Modes::Manager.instance)
      when Y2Remote::Modes::Manager.instance
        @modes.delete(Y2Remote::Modes::VNC.instance)
      end

      @modes << mode
    end
  end
end
