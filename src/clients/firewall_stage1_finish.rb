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
# File:	clients/firewall_stage1_finish.ycp
# Summary:	Installation client for writing firewall configuration
#		at the end of 1st stage
# Author:	Bubli <kmachalkova@suse.cz>
#
require "yast"

module Yast
  class FirewallStage1FinishClient < Client
    def main
      textdomain "network"

      Yast.import "Mode"
      Yast.import "Service"
      Yast.import "SuSEFirewall"
      Yast.import "SuSEFirewall4Network"

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

      Builtins.y2milestone("starting firewall_stage1_finish")
      Builtins.y2debug("func=%1", @func)
      Builtins.y2debug("param=%1", @param)

      case @func
      when "Info"
        return {
          "steps" => 1,
          # progress step title
          "title" => _(
            "Writing Firewall Configuration..."
          ),
          "when"  => [:installation, :autoinst]
        }
      when "Write"
        # Enable SSH service independent of port open (bnc#865056)
        Service.Enable("sshd") if SuSEFirewall4Network.EnabledSshd

        # This is equivalent to write-only, do not attempt to restart the service
        SuSEFirewall.WriteConfiguration
        SuSEFirewall.DisableServices if Mode.autoinst
      else
        Builtins.y2error("unknown function: %1", @func)
        @ret = nil
      end

      Builtins.y2debug("ret=%1", @ret)
      Builtins.y2milestone("firewall_stage1_finish finished")
      deep_copy(@ret)
    end
  end
end

Yast::FirewallStage1FinishClient.new.main
