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

require "yaml"

module Yast
  # Client for testing autoyast export and writes result to /tmp/test.yaml
  # DEVELOPMENT ONLY, not for production use
  class LanExportClient < Client
    def main
      Yast.import "UI"

      textdomain "network"

      # Open Trivial UI to get error messages
      Yast::UI.OpenDialog(Yast::Term.new(:PushButton, "Test"))
      WFM.CallFunction("lan_auto", ["Read"])
      res = WFM.CallFunction("lan_auto", ["Export"])
      File.write("/tmp/test.yaml", res.to_yaml)
      Yast::UI.CloseDialog

      nil
    end
  end
end

Yast::LanExportClient.new.main
