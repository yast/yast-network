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
# File:	clients/inst_netprobe
# Package:	Network configuration
# Summary:	Start the network detection
# Authors:	Michal Svec <msvec@suse.cz>
#
module Yast
  class InstNetprobeClient < Client
    def main
      Yast.import "UI"

      textdomain "network"

      Yast.import "NetHwDetection"

      Yast.include self, "network/routines.rb"

      Builtins.y2milestone("----------------------------------------")
      Builtins.y2milestone("Lan netprobe module started")
      Builtins.y2milestone("Args: %1", WFM.Args)

      @succeeded = true

      if !NetHwDetection.running
        if !NetHwDetection.Start
          Builtins.y2milestone("Network hardware detection failed.")
          @succeeded = false
        end
      end

      if NetHwDetection.running
        # Start interfaces iff running installation. See bnc#395014, bnc#782283 and bnc#792985
        SetAllLinksUp()
      end

      Builtins.y2milestone(
        "Lan netprobe module finished ... %1",
        @succeeded ? "OK" : "Failed"
      )
      Builtins.y2milestone("----------------------------------------")

      :auto
    end
  end
end

Yast::InstNetprobeClient.new.main
