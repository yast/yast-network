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
  class RoutinesClient < Client
    def main
      Yast.import "UI"
      Yast.import "Testsuite"
      @READ = { "target" => { "tmpdir" => "/tmp", "stat" => {} } }
      Testsuite.Init([@READ], 0)

      Yast.include self, "testsuite.rb"

      Yast.include self, "network/routines.rb"

      Testsuite.Dump("list2items")
      Testsuite.Test(lambda { list2items(["x", "y"], 0) }, [], nil)

      Testsuite.Dump("hwlist2items")
      Testsuite.Test(lambda do
        hwlist2items([{ "name" => "x" }, { "name" => "y" }], 0)
      end, [], nil)

      nil
    end
  end
end

Yast::RoutinesClient.new.main
