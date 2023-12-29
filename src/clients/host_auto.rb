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
# File:  clients/host_auto.ycp
# Package:  Network configuration
# Summary:  Client for autoinstallation
# Authors:  Michal Svec <msvec@suse.cz>
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
      Yast.import "AutoInstall"

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
      case @func
      when "Summary"
        @ret = Host.Summary
      # Reset configuration
      when "Reset"
        Host.Import({})
        @ret = {}
      # Change configuration (run AutoSequence)
      when "Change"
        Wizard.CreateDialog
        Wizard.SetDesktopTitleAndIcon("host")
        Wizard.SetNextButton(:next, Label.FinishButton)
        @ret = HostsMainDialog(false)
        Wizard.CloseDialog
      # Import configuration
      when "Import"
        @hosts = Ops.get_list(@param, "hosts", [])
        @hostlist = Builtins.listmap(@hosts) do |host|
          {
            Ops.get_string(host, "host_address", "error") => Ops.get_list(
              host,
              "names",
              []
            )
          }
        end
        @ret = Host.Import("hosts" => @hostlist)
      # Return actual state
      when "Export"
        @ret1 = Host.Export
        @hosts = Ops.get_map(@ret1, "hosts", {})
        @ret2 = Builtins.maplist(@hosts) do |hostaddress, names|
          { "host_address" => hostaddress, "names" => names }
        end
        @ret = if Ops.greater_than(Builtins.size(@ret2), 0)
          { "hosts" => @ret2 }
        else
          {}
        end
      # Read current state
      when "Read"
        Yast.import "Progress"
        @progress_orig = Progress.set(false)
        @ret = Host.Read
        Progress.set(@progress_orig)
      when "Packages"
        @ret = {}
      # Write givven settings
      when "Write"
        Yast.import "Progress"
        @progress_orig = Progress.set(false)
        @ret = Host.Write
        Progress.set(@progress_orig)
      when "SetModified"
        # SetModified always return(ed) true anyway
        @ret = true
      when "GetModified"
        # When cloning the sequence of this client callbacks invocation is
        # Read -> SetModified -> GetModified so it should return always true
        # (bcs of SetModified)
        @ret = true
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
