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
# File:	clients/host_auto.ycp
# Package:	Network configuration
# Summary:	Client for autoinstallation
# Authors:	Michal Svec <msvec@suse.cz>
#
#
# This is a client for autoinstallation. It takes its arguments,
# goes through the configuration and return the setting.
# Does not do any changes to the configuration.

# @param first a map of host settings
# @return [Boolean] success of operation
# @example map mm = $[ "FAIL_DELAY" : "77" ];
# @example map ret = WFM::CallFunction("host_auto", [ mm ]);
module Yast
  class HostAutoClient < Client
    def main
      Yast.import "UI"

      textdomain "network"

      Builtins.y2milestone("----------------------------------------")
      Builtins.y2milestone("Host auto started")

      Yast.import "Host"
      Yast.import "Label"
      Yast.import "Wizard"

      Yast.include self, "network/services/host.rb"

      @ret = nil
      @func = ""
      @param = {}

      # Check arguments
      if Ops.greater_than(Builtins.size(WFM.Args), 0) &&
          Ops.is_string?(WFM.Args(0))
        @func = Convert.to_string(WFM.Args(0))
        if Ops.greater_than(Builtins.size(WFM.Args), 1) &&
            Ops.is_map?(WFM.Args(1))
          @param = Convert.to_map(WFM.Args(1))
        end
      end
      Builtins.y2debug("func=%1", @func)
      Builtins.y2debug("param=%1", @param)

      # Create a summary
      if @func == "Summary"
        @ret = Host.Summary
      # Reset configuration
      elsif @func == "Reset"
        Host.Import({})
        @ret = {}
      # Change configuration (run AutoSequence)
      elsif @func == "Change"
        Wizard.CreateDialog
        Wizard.SetDesktopTitleAndIcon("host")
        Wizard.SetNextButton(:next, Label.FinishButton)
        @ret = HostsMainDialog(false)
        Wizard.CloseDialog
      # Import configuration
      elsif @func == "Import"
        @ret = Host.Import(@param)
      # Return actual state
      elsif @func == "Export"
        @ret = Host.Export
      # Read current state
      elsif @func == "Read"
        Yast.import "Progress"
        @progress_orig = Progress.set(false)
        @ret = Host.Read
        Progress.set(@progress_orig)
      elsif @func == "Packages"
        @ret = {}
      # Write givven settings
      elsif @func == "Write"
        Yast.import "Progress"
        @progress_orig = Progress.set(false)
        @ret = Host.Write
        Progress.set(@progress_orig)
      elsif @func == "SetModified"
        @ret = Host.SetModified
      elsif @func == "GetModified"
        @ret = Host.GetModified
      else
        Builtins.y2error("Unknown function: %1", @func)
        @ret = false
      end

      Builtins.y2debug("ret=%1", @ret)
      Builtins.y2milestone("Host auto finished")
      Builtins.y2milestone("----------------------------------------")

      deep_copy(@ret)

      # EOF
    end
  end
end

Yast::HostAutoClient.new.main
