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
module Yast
  class HostClient < Client
    def main
      Yast.include self, "testsuite.rb"

      @READ = {
        "target" => { "size" => 1, "tmpdir" => "/tmp" },
        "etc"    => {
          "hosts" => {
            "127.0.0.1" => ["localhost localhost.localdomain"],
            "10.0.0.1"  => ["somehost.example.com  notice-two-spaces"]
          }
        }
      }

      TESTSUITE_INIT([@READ], nil)

      Yast.import "Assert"
      Yast.import "Host"
      Yast.import "Progress"
      Progress.off

      DUMP("Read")
      TEST(-> { Host.Read }, [@READ], nil)

      names = Host.name_map["10.0.0.1"]
      Host.Update("", "newname", ["10.0.0.42"])

      new_names = Host.name_map["10.0.0.1"]
      Assert.Equal(names, new_names)

      nil
    end
  end
end

Yast::HostClient.new.main
