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
# testedfiles: Provider.ycp Testsuite.ycp
module Yast
  class ProviderClient < Client
    def main
      Yast.include self, "testsuite.rb"
      Yast.import "Pkg"

      @READ = {
        "sysconfig" => {
          "network"  => {
            "providers" => {
              "s" => {
                "first"  => { "PROVIDER" => "first one" },
                "second" => { "PROVIDER" => "second one" },
                "third"  => { "PROVIDER" => "third one" }
              },
              "v" => {
                "first"  => { "PROVIDER" => "first one" },
                "second" => { "PROVIDER" => "second one" },
                "third"  => { "PROVIDER" => "third one" }
              }
            }
          },
          "language" => { "DEFAULT_LANGUAGE" => "" }
        },
        "providers" => {
          "s" => {
            "CZ" => nil,
            "DE" => nil,
            "GB" => nil,
            "HU" => nil,
            "NL" => nil,
            "US" => nil
          }
        },
        "target"    => {
          "yast2"   => { "CZ" => "Czech" },
          "symlink" => nil,
          "tmpdir"  => "/tmp",
          "size"    => -1
        },
        "probe"     => { "display" => [], "system" => [] }
      }

      @EXEC = { "target" => { "bash_output" => {} } }

      TESTSUITE_INIT([@READ, {}, @EXEC], nil)
      Yast.import "Provider"

      DUMP("Read")
      TEST(lambda { Provider.Read }, [@READ, {}, @EXEC], nil) 

      # DUMP("GetProvider");
      # TEST(``(Provider::ReadProvider(.path.to.provider)), [READ], nil);
      # TEST(``(Provider::ReadProvider(.path.to."provi der")), [READ], nil);

      nil
    end
  end
end

Yast::ProviderClient.new.main
