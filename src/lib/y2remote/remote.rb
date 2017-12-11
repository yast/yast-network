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
require "y2remote/display_manager"

module Y2Remote
  class Remote
    include Singleton
    include Yast::Logger
    include Yast::I18n

    GRAPHICAL_TARGET = "graphical".freeze

    FIREWALL_SERVICES_PACKAGE = "xorg-x11-Xvnc".freeze

    # List of Y2Remote::Modes::Base subclasses that are the enabled VNC running
    # modes
    attr_reader :modes

    # [Boolean] whether the configuration has been proposed or not
    attr_accessor :proposed

    alias_method :proposed?, :proposed

    # Constructor
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

    # Enables the Y2Remote::Modes::VNC mode
    def enable!
      enable_mode!(Y2Remote::Modes::VNC.instance)
    end

    # Enables the Y2Remote::Modes::Manager mode
    def enable_manager!
      enable_mode!(Y2Remote::Modes::Manager.instance)
    end

    # Enables the Y2Remote::Modes::Web mode
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

    def display_manager
      @display_manager ||= Y2Remote::DisplayManager.instance
    end

    # Read the current status of vnc and the enabled modes
    #
    # @return [Boolean] true
    def read
      return true unless display_manager.remote_access?

      @modes = Y2Remote::Modes.running_modes

      true
    end

    # Update the SCR according to vnc settings
    #
    # @return [Boolean] true on success
    def write
      configure_write_steps

      next_stage(_("Configuring display manager..."))
      return false unless configure_display_manager

      if Yast::Mode.normal
        next_stage(_("Restarting the service..."))
        restart_services
        next_stage
      end

      true
    end

    # Reset the proposal configuration enabling vnc if it was enabled by
    # linuxrc
    def reset!
      @proposed = false

      propose!
    end

    # Propose the vnc configuration if it has not been proposed yet
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

      display_manager.write_remote_access(enabled?)
    end

    # Restarts services, reporting errors to the user
    def restart_services
      Yast::SystemdTarget.set_default(GRAPHICAL_TARGET) if enabled?

      Y2Remote::Modes.restart_modes

      display_manager.restart if enabled?
    end

    # Return a summary of the current remote configuration
    #
    # @return [String] summary text
    def summary
      return _("Remote administration is enabled.") if enabled?

      _("Remote administration is disabled.")
    end

  private

    # Convenience method to import YaST module dependencies
    def import_modules
      Yast.import "Mode"
      Yast.import "Package"
      Yast.import "Progress"
      Yast.import "Linuxrc"
      Yast.import "Message"
      Yast.import "SystemdTarget"
    end

    # Obtains a list of the required packages for the enabled vnc modes
    def required_packages
      modes.map(&:required_packages).flatten
    end

    # Adds the given mode to the list of modes to be enabled
    #
    # @param mode [Y2Remote::Modes::Base] running mode to be enabled
    # @return [Array<Y2Remote::Modes::Base>] list of enable running modes
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

    def configure_write_steps
      steps = [_("Configure display manager")]
      steps << _("Restart the services") if Yast::Mode.normal

      caption = _("Saving Remote Administration Configuration")

      Yast::Progress.New(caption, " ", steps.size, steps, [], "")
    end

    def next_stage(title = nil)
      Yast::Progress.NextStage
      Yast::Progress.Title(title) if title
    end
  end
end
