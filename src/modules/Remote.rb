# encoding: utf-8

#***************************************************************************
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
#**************************************************************************
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

    PKG_CONTAINING_FW_SERVICES = "xorg-x11-Xvnc"

    def main
      Yast.import "UI"
      textdomain "network"

      Yast.import "Label"
      Yast.import "Mode"
      Yast.import "Package"
      Yast.import "Service"
      Yast.import "SuSEFirewall"
      Yast.import "Progress"
      Yast.import "Linuxrc"
      Yast.import "String"
      Yast.import "FileUtils"
      Yast.import "Message"

      Yast.include self, "network/routines.rb"

      # security types supported by Xvnc
      @SEC_NONE = "none"
      @SEC_VNCAUTH = "vncauth"

      @SEC_TYPES = [@SEC_NONE, @SEC_VNCAUTH]

      @SEC_OPT_SECURITYTYPE = "securitytypes"

      # Currently, all attributes (enablement of remote access)
      # are applied on vnc1 even vnchttpd1 configuration

      # Allow remote administration
      @allow_administration = false

      # Default display manager
      @default_dm = "xdm"

      # Remote administration has been already proposed
      # Only force-reset can change it
      @already_proposed = false
    end

    # Checks if remote administration is currently allowed
    def IsEnabled
      @allow_administration
    end

    # Checks if remote administration is currently disallowed
    def IsDisabled
      !IsEnabled()
    end

    # Enables remote administration.
    def Enable
      @allow_administration = true

      nil
    end

    # Disables remote administration.
    def Disable
      @allow_administration = false

      nil
    end

    # Reset all module data.
    def Reset
      @already_proposed = true

      # Bugzilla #135605 - enabling Remote Administration when installing using VNC
      @allow_administration = Linuxrc.vnc

      Builtins.y2milestone(
        "Remote Administration was proposed as: %1",
        @allow_administration ? "enabled" : "disabled"
      )

      nil
    end

    # Function proposes a configuration
    # But only if it hasn't been proposed already
    def Propose
      Reset() if !@already_proposed

      nil
    end

    # Removes all options <option> (and its value) from <server_args>
    #
    # Note: server_args has to be valid. In case of incorrect input (e.g. -opt1= -opt2)
    # is result undefined.
    #
    # @param [String] server_args   list of options as provided by server_args attribute in
    #                      /etc/xinet.d/vnc
    # @param [String] option        option name. Typically alphanumeric string. If a regexp special
    #                      characters are used behavior is undefined.
    # @param [Boolean] has_value     if true then option is expected to be followed by a value
    #
    # @return              modified server_args string in case of success unchanged
    #                      server_args otherwise
    def ServerArgsRemoveOpt(server_args, option, has_value)
      return server_args if IsEmpty(server_args) || IsEmpty(option)

      # Note: value (e.g. filename in -passwdfile) cannot be quoted (a bug in Xvnc ?).
      # valid forms are:
      # e.g. -file=path_to_file or
      # e.g. -file path_to_file
      value_pattern_nquote = "[=[:space:]][^[:space:]]+"
      pattern = Builtins.sformat(
        "[[:space:]]*[-]{0,2}%1%2",
        option,
        has_value ? value_pattern_nquote : ""
      )

      # Xvnc:
      # - is case insensitive to option names.
      # - option can be prefixed by 0 or up to 2 dashes
      # - option and value can be separated by space or =
      new_server_args = server_args.downcase

      new_server_args = String.CutRegexMatch(new_server_args, pattern, true)

      new_server_args
    end

    # Add given option and its value to server_args.
    #
    # If option is present already then all occurences of option are removed.
    # New option value pair is added subsequently.
    def SetServerArgsOpt(server_args, option, value)
      new_server_args = ServerArgsRemoveOpt(
        server_args,
        option,
        IsNotEmpty(value)
      )
      new_server_args = Builtins.sformat(
        "%1 -%2 %3",
        new_server_args,
        option,
        value
      )

      String.CutBlanks(new_server_args)
    end

    # Appends option for particular security type.
    #
    # @param [String] server_args   string with server options as written in xinetd cfg file
    # @param [String] sec_type      a security type supported by Xvnc (see man xvnc)
    #
    # @return              server_args with appended option for particular sec_type
    #                      if sec_type is valid. Unchanged server_args otherwise.
    def SetSecurityType(server_args, sec_type)
      # validate sec_type
      return server_args if !@SEC_TYPES.include?(sec_type)

      SetServerArgsOpt(server_args, @SEC_OPT_SECURITYTYPE, sec_type)
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
        :from => "any",
        :to   => "list <map>"
      )
      vnc_conf = Builtins.filter(xinetd_conf) do |m|
        s = Ops.get_string(m, "service", "")
        s == "vnc1" || s == "vnchttpd1"
      end
      vnc = Builtins.size(vnc_conf) == 2 &&
        Ops.get_boolean(vnc_conf, [0, "enabled"], false) &&
        Ops.get_boolean(vnc_conf, [1, "enabled"], false)

      log.info "#{XDM_SERVICE_NAME}: #{xdm}, DM_R_A: #{dm_ra}"
      log.info "xinetd: #{xinetd}, VNC: #{vnc}"

      @allow_administration = xdm && dm_ra && xinetd && vnc

      # Package containing SuSEfirewall2 services has to be installed before
      # reading SuSEFirewall, otherwise exception is thrown by firewall
      if Package.Install(PKG_CONTAINING_FW_SERVICES)
        current_progress = Progress.set(false)
        SuSEFirewall.Read
        Progress.set(current_progress)
      else
        Report.Error(
          _("Package %{package} is not installed\nfirewall settings will be disabled.") % {
            :package => PKG_CONTAINING_FW_SERVICES
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
        :from => "any",
        :to   => "list <map>"
      )

      xinetd = Builtins.maplist(xinetd) do |m|
        s = Ops.get_string(m, "service", "")
        next deep_copy(m) if !(s == "vnc1" || s == "vnchttpd1")
        Ops.set(m, "changed", true)
        Ops.set(m, "enabled", @allow_administration)
        server_args = Ops.get_string(m, "server_args", "")
        if @allow_administration
          # use none authentication, xdm will take care of it
          Ops.set(m, "server_args", SetSecurityType(server_args, @SEC_NONE))
        else
          # switch back to default when remote administration is disallowed.
          Ops.set(
            m,
            "server_args",
            ServerArgsRemoveOpt(server_args, @SEC_OPT_SECURITYTYPE, true)
          )
        end
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

      if @allow_administration
        # Install required packages
        packages = ["xinetd", "xorg-x11", PKG_CONTAINING_FW_SERVICES]

        #At least one windowmanager must be installed (#427044)
        #If none is, there, use icewm as fallback
        #Package::Installed uses rpm -q --whatprovides
        packages << "icewm" unless Package.Installed("windowmanager")

        if !Package.InstallAll(packages)
          log.error "Installing of required packages failed"
          return false
        end

        # Enable xinetd
        if !Service.Enable(XINETD_SERVICE)
          Report.Error(
            _("Enabling service %{service} has failed") % { :service => XINETD_SERVICE }
          )
          return false
        end

        # Enable XDM
        if !Service.Enable(XDM_SERVICE_NAME)
          Report.Error(
            _("Enabling service %{service} has failed") % { :service => XDM_SERVICE_NAME }
          )
          return false
        end
      end

      # Set DISPLAYMANAGER_REMOTE_ACCESS in sysconfig/displaymanager
      SCR.Write(
        path(".sysconfig.displaymanager.DISPLAYMANAGER_REMOTE_ACCESS"),
        @allow_administration ? "yes" : "no"
      )
      SCR.Write(
        path(".sysconfig.displaymanager.DISPLAYMANAGER_ROOT_LOGIN_REMOTE"),
        @allow_administration ? "yes" : "no"
      )
      SCR.Write(path(".sysconfig.displaymanager"), nil)

      #Query xinetd presence here (it might not have been even installed before)
      have_xinetd = Package.Installed("xinetd")

      #Do this only if package xinetd is installed (#256385)
      return false if have_xinetd && !WriteXinetd()

      if Mode.normal
        ProgressNextStage(_("Restarting the service..."))

        if @allow_administration
          SCR.Write(path(".etc.inittab.id"), "5:initdefault:")
          SCR.Write(path(".etc.inittab"), nil)

          #if allow_administration is set to true, xinetd must be already installed
          Report.Error(Message.CannotRestartService(XINETD_SERVICE)) unless Service.Restart(XINETD_SERVICE)
          Report.Error(Message.CannotRestartService(XDM_SERVICE_NAME)) unless Service.Restart(XDM_SERVICE_NAME)
        else
          if have_xinetd
            # xinetd may be needed for other services so we never turn it
            # off. It will exit anyway if no services are configured.
            # If it is running, restart it.
            Service.Restart(XINETD_SERVICE) if Service.active?(XINETD_SERVICE)
          end
        end

        # do not call '$service reload' for gdm - use SuSEconfig
        # TODO: confirm that it's still needed
        if @default_dm != "gdm"
          Service.Reload(XDM_SERVICE_NAME)
        end

        Progress.NextStage
      end

      true
    end

    # Create summary
    # @return summary text
    def Summary
      # description in proposal
      @allow_administration ? _("Remote administration is enabled.") : _("Remote administration is disabled.")
    end

    publish :variable => :SEC_NONE, :type => "const string"
    publish :variable => :SEC_VNCAUTH, :type => "const string"
    publish :variable => :SEC_TYPES, :type => "list <string>"
    publish :variable => :SEC_OPT_SECURITYTYPE, :type => "const string"
    publish :variable => :default_dm, :type => "string"
    publish :function => :IsEnabled, :type => "boolean ()"
    publish :function => :IsDisabled, :type => "boolean ()"
    publish :function => :Enable, :type => "void ()"
    publish :function => :Disable, :type => "void ()"
    publish :function => :Reset, :type => "void ()"
    publish :function => :Propose, :type => "void ()"
    publish :function => :Read, :type => "boolean ()"
    publish :function => :Write, :type => "boolean ()"
    publish :function => :Summary, :type => "string ()"
  end

  Remote = RemoteClass.new
  Remote.main
end
