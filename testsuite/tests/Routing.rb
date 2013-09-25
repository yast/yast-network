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
  class RoutingClient < Client
    def main
      # testedfiles: Routing.ycp Testsuite.ycp

      Yast.include self, "testsuite.rb"

      @READ = {
        "target"    => { "size" => 1, "tmpdir" => "/tmp" },
        "routes"    => [{ "1" => "r1" }, { "2" => "r2" }],
        "probe"     => { "system" => [] },
        "product"   => {
          "features" => {
            "USE_DESKTOP_SCHEDULER" => "0",
            "ENABLE_AUTOLOGIN"      => "0",
            "EVMS_CONFIG"           => "0",
            "IO_SCHEDULER"          => "cfg",
            "UI_MODE"               => "expert"
          }
        },
        "sysconfig" => {
          "language" => {
            "RC_LANG"          => "",
            "DEFAULT_LANGUAGE" => "",
            "ROOT_USES_LANG"   => "no"
          },
          "console"  => { "CONSOLE_ENCODING" => "UTF-8" }
        },
        "etc"       => { 
          "sysctl_conf" => { 
            "net.ipv4.ip_forward" => "1",
            "net.ipv6.conf.all.forwarding" => "1"  
          } 
        }
      }

      @EXEC = {
        "target" =>
          # simluate not running SuSEFirewall
          { "bash_output" => {}, "bash" => -1 }
      }

      TESTSUITE_INIT([@READ, {}, @EXEC], nil)
      Yast.import "Routing"

      DUMP("==== Read =====")
      TEST(lambda { Routing.Read }, [@READ, {}, @EXEC], nil)
      DUMP(Builtins.sformat("Routing::routes %1", Routing.Routes))

      DUMP("==== Write ====")
      # Routing::Forward = true;
      TEST(lambda { Routing.Write }, [@READ], nil)
      Routing.Routes = [{ "1" => "r1" }, { "3" => "r3" }]
      TEST(lambda { Routing.Write }, [@READ], nil)

      DUMP("==== Import ====")
      TEST(lambda do
        Routing.Import({ "routes" => ["r7", "r8"], "ip_forward" => true })
      end, [], nil)

      DUMP("==== Export ====")
      TEST(lambda { Routing.Export }, [], nil)

      nil
    end
  end
end

Yast::RoutingClient.new.main
