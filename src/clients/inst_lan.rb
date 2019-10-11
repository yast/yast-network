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
# File:  clients/lan.ycp
# Package:  Network configuration
# Summary:  Network cards main file
# Authors:  Michal Svec <msvec@suse.cz>
#
#
# Main file for network card configuration.
# Uses all other files.
module Yast
  class InstLanClient < Client
    include Logger

    def main
      Yast.import "UI"
      Yast.import "Lan"
      Yast.import "GetInstArgs"

      Yast.include self, "network/lan/wizards.rb"

      textdomain "network"

      log.info("----------------------------------------")
      log.info("Lan module started")

      manual_conf_request = GetInstArgs.argmap["skip_detection"] || false
      log.info("Lan module forces manual configuration: #{manual_conf_request}")

      # keep network configuration state in @@conf_net to gurantee same
      # behavior when walking :back in installation workflow
      @@network_configured = !Yast::Lan.yast_config.connections.empty? if !defined?(@@network_configured)

      log.info("Configured network found: #{@@network_configured}")

      ret = if @@network_configured && !manual_conf_request
        GetInstArgs.going_back ? :back : :next
      else
        LanSequence()
      end

      log.info("Lan module finished, ret = #{ret}")
      log.info("----------------------------------------")

      ret
    end
  end

  Yast::InstLanClient.new.main
end
