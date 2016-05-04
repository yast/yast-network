# encoding: utf-8

# ***************************************************************************
#
# Copyright (c) 2012 Novell, Inc.
# All Rights Reserved.
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of version 2 of the GNU General Public License as
# published by the Free Software Foundation.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.   See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, contact Novell, Inc.
#
# To contact Novell about this file by physical or electronic mail,
# you may find current contact information at www.novell.com
#
# **************************************************************************
# File:	src/modules/Remote.ycp
# Module:	Network configuration
# Summary:	Module for Remote Administration via VNC
# Authors:	Arvin Schnell <arvin@suse.de>
#		Martin Vidner <mvidner@suse.cz>
#
#
require "yast"

module Yast
  class RemoteClass < Module
    include Yast::Logger

    XDM_SERVICE_NAME = "display-manager"
    XINETD_SERVICE = "xinetd"
    VNCMANAGER_SERVICE = "vncmanager"

    PKG_CONTAINING_FW_SERVICES = "xorg-x11-Xvnc"
    PKG_CONTAINING_VNCMANAGER = "vncmanager"

    GRAPHICAL_TARGET = "graphical"

    def main
      textdomain "network"

      Yast.import "Mode"
      Yast.import "Package"
      Yast.import "Packages"
      Yast.import "Service"
      Yast.import "SuSEFirewall"
      Yast.import "Progress"
      Yast.import "Linuxrc"
      Yast.import "Message"
      Yast.import "SystemdTarget"

      Yast.include self, "network/routines.rb"

      # Currently, all attributes (enablement of remote access)
      # are applied on vnc1 even vnchttpd1 configuration

      # Remote administration mode, :disabled, :xinetd or :vncmanager
      @mode = :disabled

      # Default display manager
      @default_dm = "xdm"

      # Remote administration has been already proposed
      # Only force-reset can change it
      @already_proposed = false
    end

    # Retrieves the current remote administration mode
    def Mode
      @mode
    end

    # Sets the remtoe administration mode
    def SetMode(mode)
      @mode = mode

      nil
    end

    # Checks if remote administration is currently allowed
    def IsEnabled
      !IsDisabled()
    end

    # Checks if remote administration is currently disallowed
    def IsDisabled
      @mode == :disabled
    end

    # Enables remote administration.
    def Enable
      SetMode(:xinetd)

      nil
    end

    # Disables remote administration.
    def Disable
      SetMode(:disabled)

      nil
    end

    # Reset all module data.
    def Reset
      @already_proposed = true

      # Bugzilla #135605 - enabling Remote Administration when installing using VNC
      @mode = Linuxrc.vnc ? :xinetd : :disabled

      Builtins.y2milestone(
        "Remote Administration was proposed as: %1",
        IsEnabled() ? "enabled" : "disabled"
      )

      nil
    end

    # Function proposes a configuration
    # But only if it hasn't been proposed already
    def Propose
      Reset() if !@already_proposed

      nil
    end

    # Read the current status
    # @return true on success
    def Read
      xdm = Service.Enabled(XDM_SERVICE_NAME)
      dm_ra = Convert.to_string(
        SCR.Read(path(".sysconfig.displaymanager.DISPLAYMANAGER_REMOTE_ACCESS"))
      ) == "yes"
      @default_dm = Convert.to_string(
        SCR.Read(path(".sysconfig.displaymanager.DISPLAYMANAGER"))
      )

      xinetd = Service.Enabled(XINETD_SERVICE)
      # are the proper services enabled in xinetd?
      xinetd_conf = Convert.convert(
        SCR.Read(path(".etc.xinetd_conf.services")),
        from: "any",
        to:   "list <map>"
      )

      xinetd_vnc1_enabled = false
      xinetd_vnchttp1_enabled = false
      vnc_conf = xinetd_conf.each do |m|
        xinetd_vnc1_enabled = !!m["enabled"] if m["service"] == "vnc1"
        xinetd_vnchttp1_enabled = !!m["enabled"] if m["service"] == "vnchttpd1"
      end

      log.info "#{XDM_SERVICE_NAME}: #{xdm}, DM_R_A: #{dm_ra}"
      log.info "xinetd: #{xinetd}, VNC1: #{xinetd_vnc1_enabled}, VNCHTTP1: #{xinetd_vnchttp1_enabled}"

      vncmanager = Service.Enabled(VNCMANAGER_SERVICE)

      @mode = :disabled

      if xdm && dm_ra && xinetd && xinetd_vnchttp1_enabled
        @mode = :xinetd if xinetd_vnc1_enabled && !vncmanager
        @mode = :vncmanager if !xinetd_vnc1_enabled && vncmanager
      end

      # Package containing SuSEfirewall2 services has to be installed before
      # reading SuSEFirewall, otherwise exception is thrown by firewall
      if Package.Install(PKG_CONTAINING_FW_SERVICES)
        current_progress = Progress.set(false)
        SuSEFirewall.Read
        Progress.set(current_progress)
      else
        Report.Error(
          _("Package %{package} is not installed\nfirewall settings will be disabled.") % {
            package: PKG_CONTAINING_FW_SERVICES
          }
        )
      end

      true
    end

    def WriteXinetd
      # Enable/disable vnc1 and vnchttpd1 in xinetd.d/vnc
      # If the port is changed, change also the help in remote/dialogs.ycp
      # The agent is in yast2-inetd.rpm
      xinetd = Convert.convert(
        SCR.Read(path(".etc.xinetd_conf.services")),
        from: "any",
        to:   "list <map>"
      )

      xinetd = Builtins.maplist(xinetd) do |m|
        s = Ops.get_string(m, "service", "")
        next deep_copy(m) if !(s == "vnc1" || s == "vnchttpd1")
        Ops.set(m, "changed", true)
        Ops.set(m, "enabled", @mode == :xinetd) if s == "vnc1"
        Ops.set(m, "enabled", @mode != :disabled) if s == "vnchttpd1"
        log.info "Updated xinet cfg: #{m}"
        deep_copy(m)
      end

      SCR.Write(path(".etc.xinetd_conf.services"), xinetd)

      true
    end

    # Update the SCR according to network settings
    # @return true on success
    def Write
      steps = [
        # Progress stage 1
        _("Write firewall settings"),
        # Progress stage 2
        _("Configure display manager")
      ]

      if Mode.normal
        # Progress stage 3
        steps << _("Restart the services")
      end

      caption = _("Saving Remote Administration Configuration")

      Progress.New(caption, " ", Builtins.size(steps), steps, [], "")

      ProgressNextStage(_("Writing firewall settings..."))
      current_progress = Progress.set(false)
      SuSEFirewall.Write
      Progress.set(current_progress)

      ProgressNextStage(_("Configuring display manager..."))
      return false unless configure_display_manager

      if Mode.normal
        ProgressNextStage(_("Restarting the service..."))
        restart_services
        Progress.NextStage
      end

      true
    end

    # Updates the VNC and xdm configuration
    #
    # Called from #Write. Ensures that required packages are installed,
    # enables xinetd and xdm and writes the configuration files, reporting
    # any error in the process.
    #
    # @return [Boolean] true if success, false otherwise
    def configure_display_manager
      if IsEnabled()
        # Install required packages
        packages = Packages.vnc_packages
        packages << PKG_CONTAINING_VNCMANAGER if Mode() == :vncmanager

        if !Package.InstallAll(packages)
          log.error "Installing of required packages failed"
          return false
        end

        services = [
          [ XINETD_SERVICE, true ],
          [ XDM_SERVICE_NAME, true ],
          [ VNCMANAGER_SERVICE, @mode == :vncmanager ]
        ]

        services.each do |service, enable|
          if enable
            if !Service.Enable(service)
              Report.Error(
                _("Enabling service %{service} has failed") % { service: service }
              )
              return false
            end
          else
            if !Service.Disable(service)
              Report.Error(
                _("Disabling service %{service} has failed") % { service: service }
              )
              return false
            end
          end
        end
      end

      # Set DISPLAYMANAGER_REMOTE_ACCESS in sysconfig/displaymanager
      SCR.Write(
        path(".sysconfig.displaymanager.DISPLAYMANAGER_REMOTE_ACCESS"),
        IsEnabled() ? "yes" : "no"
      )
      SCR.Write(
        path(".sysconfig.displaymanager.DISPLAYMANAGER_ROOT_LOGIN_REMOTE"),
        IsEnabled() ? "yes" : "no"
      )
      SCR.Write(path(".sysconfig.displaymanager"), nil)

      # Do this only if package xinetd is installed (#256385)
      return false if Package.Installed("xinetd") && !WriteXinetd()

      true
    end

    def restart_display_manager
      if Service.active?(XDM_SERVICE_NAME)
        Report.Error(Message.CannotRestartService(XDM_SERVICE_NAME)) unless Service.Reload(XDM_SERVICE_NAME)
        Report.Warning(
          _(
            "Your display manager must be restarted.\n" \
            "To take the changes in remote administration into account, \n" \
            "please restart it manually or log out and log in again."
          )
        )
      else
        Report.Error(Message.CannotRestartService(XDM_SERVICE_NAME)) unless Service.Restart(XDM_SERVICE_NAME)
      end
    end

    # Restarts xinetd and xdm, reporting errors to the user
    def restart_services
      if IsEnabled()
        SystemdTarget.set_default(GRAPHICAL_TARGET)

        Report.Error(Message.CannotRestartService(XINETD_SERVICE)) unless Service.Restart(XINETD_SERVICE)

        if @mode == :vncmanager
          Report.Error(Message.CannotRestartService(VNCMANAGER_SERVICE)) unless Service.Restart(VNCMANAGER_SERVICE)
        end

        restart_display_manager
      else
        # xinetd may be needed for other services so we never turn it
        # off. It will exit anyway if no services are configured.
        # If it is running, restart it.
        Service.Reload(XINETD_SERVICE) if Service.active?(XINETD_SERVICE)

        Service.Stop(VNCMANAGER_SERVICE)
      end
    end

    # Create summary
    # @return summary text
    def Summary
      # description in proposal
      IsEnabled() ? _("Remote administration is enabled.") : _("Remote administration is disabled.")
    end

    publish variable: :default_dm, type: "string"
    publish function: :IsEnabled, type: "boolean ()"
    publish function: :IsDisabled, type: "boolean ()"
    publish function: :Enable, type: "void ()"
    publish function: :Disable, type: "void ()"
    publish function: :Reset, type: "void ()"
    publish function: :Propose, type: "void ()"
    publish function: :Read, type: "boolean ()"
    publish function: :Write, type: "boolean ()"
    publish function: :Summary, type: "string ()"
  end

  Remote = RemoteClass.new
  Remote.main
end
