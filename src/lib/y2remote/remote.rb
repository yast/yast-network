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

    PKG_CONTAINING_FW_SERVICES = "xorg-x11-Xvnc".freeze

    # Currently, all attributes (enablement of remote access)
    # are applied on vnc1 even vnchttpd1 configuration

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

    # Checks if remote administration is currently disallowed
    def disabled?
      modes.empty?
    end

    def disable!
      @modes = []
    end

    # It add the given mode to the list of modes to be enabled
    #
    # @return [Array<Symbol>] list of enable vnc modes
    def enable_mode(mode)
      return modes if modes.include?(mode)

      @modes.delete(:vnc) if mode == :manager
      @modes.delete(:manager) if mode == :vnc

      @modes << mode
    end

    # Whether the vnc manager mode is enabled or not
    #
    # @return [Boolean] true it the :manager mode is enabled
    def with_manager?
      modes.include?(:manager)
    end

    # Read the current status of vnc and the enabled modes
    #
    # @return [Boolean] true
    def read
      if xdm_enabled? && display_manager_remote_access?
        @modes = Y2Remote::Modes.running_modes
      end

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

      Yast::Linuxrc.vnc ? enable! : disable!

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

        Y2Remote::Modes.all.each { |m| modes.include?(m) ? m.enable! : m.disable! }
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

      Y2Remote::Modes.all { |m| modes.include?(m.to_sym) ? m.restart! : m.stop! }

      restart_display_manager if enabled?
    end

    def summary
      return _("Remote administration is enabled.") if remote.enabled?

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

    def required_packages
      Y2Remote::Modes.all.map do |mode|
        mode.required_packages if modes.include?(mode.to_sym)
      end.compact.flatten
    end

    def display_manager_remote_access?
      Yast::SCR.Read(Yast.path(".sysconfig.displaymanager.DISPLAYMANAGER_REMOTE_ACCESS")) == "yes"
    end

    def xdm_enabled?
      Yast::Service.Enabled(XDM_SERVICE_NAME)
    end
  end
end
