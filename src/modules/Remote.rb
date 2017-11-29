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

    XDM_SERVICE_NAME = "display-manager".freeze
    XVNC_SERVICE = "xvnc.socket".freeze
    XVNC_NOVNC_SERVICE = "xvnc-novnc.socket".freeze
    VNCMANAGER_SERVICE = "vncmanager".freeze

    PKG_CONTAINING_FW_SERVICES = "xorg-x11-Xvnc".freeze
    PKG_CONTAINING_VNCMANAGER = "vncmanager".freeze
    PKG_CONTAINING_XVNC_NOVNC = "xorg-x11-Xvnc-novnc".freeze

    GRAPHICAL_TARGET = "graphical".freeze

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

      # Remote administration mode, :disabled, :xvnc or :vncmanager
      @mode = :disabled

      # Whether a web based vnc viewer should be served
      @web_vnc_enabled = false

      # Remote administration has been already proposed
      # Only force-reset can change it
      @already_proposed = false
    end

    # Checks if remote administration is currently allowed
    def IsEnabled
      !IsDisabled()
    end

    # Checks if remote administration is currently disallowed
    def IsDisabled
      @mode == :disabled
    end

    # Enables remote administration without vnc manager.
    def Enable
      @mode = :xvnc

      nil
    end

    # Enables remote administration with vnc manager.
    def EnableVncManager
      @mode = :vncmanager

      nil
    end

    # Disables remote administration.
    def Disable
      @mode = :disabled

      nil
    end

    def EnabledVncManager
      @mode == :vncmanager
    end

    def IsWebVncEnabled
      @web_vnc_enabled
    end

    def EnableWebVnc
      @web_vnc_enabled = true
    end

    def DisableWebVnc
      @web_vnc_enabled = false
    end

    # Reset all module data.
    def Reset
      @already_proposed = true

      # Bugzilla #135605 - enabling Remote Administration when installing using VNC
      if Linuxrc.vnc
        Enable()
      else
        Disable()
      end

      log.info("Remote Administration was proposed as: #{@mode}")

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
      display_manager_remote_access = SCR.Read(path(".sysconfig.displaymanager.DISPLAYMANAGER_REMOTE_ACCESS")) == "yes"

      xdm        = Service.Enabled(XDM_SERVICE_NAME)
      vncmanager = Service.Enabled(VNCMANAGER_SERVICE)
      xvnc       = Service.Enabled(XVNC_SERVICE)
      xvnc_novnc = Service.Enabled(XVNC_NOVNC_SERVICE)

      if xdm && display_manager_remote_access && (xvnc || vncmanager)
        if xvnc
          Enable()
        else
          EnableVncManager()
        end

        EnableWebVnc() if xvnc_novnc
      else
        Disable()
        DisableWebVnc()
      end

      true
    end

    # Update the SCR according to network settings
    # @return true on success
    def Write
      if Mode.normal # running in an installed system
        # Package containing SuSEfirewall services has to be installed before
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
      end

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
    # enables vnc services and xdm and writes the configuration files,
    # reporting any error in the process.
    #
    # @return [Boolean] true if success, false otherwise
    def configure_display_manager
      if IsEnabled()
        # Install required packages
        packages = Packages.vnc_packages
        packages << PKG_CONTAINING_VNCMANAGER if EnabledVncManager()
        packages << PKG_CONTAINING_XVNC_NOVNC if IsWebVncEnabled()

        if !Package.InstallAll(packages)
          log.error "Installing of required packages failed"
          return false
        end

        services = [
          [XVNC_SERVICE, !EnabledVncManager()],
          [XDM_SERVICE_NAME, true]
        ]

        services << [VNCMANAGER_SERVICE, EnabledVncManager()] if Package.Installed(PKG_CONTAINING_VNCMANAGER)
        services << [XVNC_NOVNC_SERVICE, IsWebVncEnabled()] if Package.Installed(PKG_CONTAINING_XVNC_NOVNC)

        services.each do |service, enable|
          if enable
            if !Service.Enable(service)
              Report.Error(
                _("Enabling service %{service} has failed") % { service: service }
              )
              return false
            end
          elsif !Service.Disable(service)
            Report.Error(
              _("Disabling service %{service} has failed") % { service: service }
            )
            return false
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

    # Restarts services, reporting errors to the user
    def restart_services
      if IsEnabled()
        SystemdTarget.set_default(GRAPHICAL_TARGET)

        # Enable vncmanager or xvnc service, depending on which mode are we in
        if EnabledVncManager()
          Report.Error(Message.CannotRestartService(VNCMANAGER_SERVICE)) unless Service.Restart(VNCMANAGER_SERVICE)
        else
          Report.Error(Message.CannotRestartService(XVNC_SERVICE)) unless Service.Restart(XVNC_SERVICE)
        end

        # Enable xvnc-novnc service in addition to xvnc/vncmanager if enabled
        if IsWebVncEnabled()
          Report.Error(Message.CannotRestartService(XVNC_NOVNC_SERVICE)) unless Service.Restart(XVNC_NOVNC_SERVICE)
        else
          Service.Stop(XVNC_NOVNC_SERVICE)
        end

        restart_display_manager
      else
        Service.Stop(VNCMANAGER_SERVICE)
        Service.Stop(XVNC_SERVICE)
        Service.Stop(XVNC_NOVNC_SERVICE)
      end
    end

    # Create summary
    # @return summary text
    def Summary
      # description in proposal
      IsEnabled() ? _("Remote administration is enabled.") : _("Remote administration is disabled.")
    end

    publish function: :IsEnabled, type: "boolean ()"
    publish function: :IsDisabled, type: "boolean ()"
    publish function: :Enable, type: "void ()"
    publish function: :Disable, type: "void ()"
    publish function: :EnableVncManager, type: "void ()"
    publish function: :EnabledVncManager, type: "boolean ()"
    publish function: :IsWebVncEnabled, type: "boolean ()"
    publish function: :EnableWebVnc, type: "void ()"
    publish function: :DisableWebVnc, type: "void ()"
    publish function: :Reset, type: "void ()"
    publish function: :Propose, type: "void ()"
    publish function: :Read, type: "boolean ()"
    publish function: :Write, type: "boolean ()"
    publish function: :Summary, type: "string ()"
  end

  Remote = RemoteClass.new
  Remote.main
end
