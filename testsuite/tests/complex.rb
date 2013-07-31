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
module Yast
  class ComplexClient < Client
    def main
      Yast.import "UI"

      # testedfiles: complex.ycp Testsuite.ycp
      Yast.import "Testsuite"
      @READ = { "target" => { "tmpdir" => "/tmp", "stat" => {} } }
      Testsuite.Init([@READ], 0)

      @Devs = {}
      Yast.include self, "network/complex.rb"

      @Hardware = [{ "bus" => "pci", "busid" => "1234", "name" => "hwtest" }]

      Testsuite.Dump("HardwareName")
      Testsuite.Test(lambda { HardwareName(@Hardware, "") }, [], nil)
      Testsuite.Test(lambda { HardwareName(@Hardware, "bus-pci-1234") }, [], nil)

      nil
    end
  end
end

Yast::ComplexClient.new.main
