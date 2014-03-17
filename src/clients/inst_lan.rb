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
# File:	clients/lan.ycp
# Package:	Network configuration
# Summary:	Network cards main file
# Authors:	Michal Svec <msvec@suse.cz>
#
#
# Main file for network card configuration.
# Uses all other files.
module Yast
  class InstLanClient < Client
    include Logger

    def main
      Yast.import "UI"
      Yast.import "Label"
      Yast.import "Lan"
      Yast.import "RichText"

      textdomain "network"

      log.info("----------------------------------------")
      log.info("Lan module started")

      Yast.include self, "network/lan/cmdline.rb"
      Yast.include self, "network/lan/wizards.rb"

      conf_net = LanItems.Items.keys.any? { |i| LanItems.IsItemConfigured(i) }

      log.info("Configured network found: #{conf_net}")

      ret = !conf_net ? LanSequence() : :next

      log.info("Lan module finished, ret = #{ret}")
      log.info("----------------------------------------")

      ret
    end
  end

  Yast::InstLanClient.new.main
end
