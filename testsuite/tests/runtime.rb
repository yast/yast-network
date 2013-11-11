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
  class RuntimeClient < Client
    def main

      # testedfiles: runtime.ycp Testsuite.ycp

      Yast.include self, "testsuite.rb"

      @READ = {
        "init"      => { "scripts" => { "exists" => true } },
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
        "target"    => { "size" => 1, "stat" => { "dummy" => true } }
      }

      @EXEC = { "target" => { "bash_output" => {} } }

      TESTSUITE_INIT([@READ, {}, @EXEC], nil)
      Yast.include self, "network/runtime.rb"

      @EXEC0 = {
        "target" => {
          "bash"            => 0,
          "bash_background" => 0,
          "bash_output"     => { "exit" => 0, "stdout" => "", "stderr" => "" }
        }
      }

      @EXEC1 = {
        "target" => {
          "bash"            => 1,
          "bash_background" => 1,
          "bash_output"     => {
            "exit"   => 1,
            "stdout" => "",
            "stderr" => "Dummy error message"
          }
        }
      }

      DUMP("RunSuSEconfig")
      TEST(lambda { RunSuSEconfig() }, [{}, {}, @EXEC0], nil)
      TEST(lambda { RunSuSEconfig() }, [{}, {}, @EXEC1], nil)

      Yast.import "NetworkInterfaces"
      NetworkInterfaces.instance_variable_set(:@Devices, { "dsl" => { "0" => {} } })

      DUMP("SetupSMPPPD")
      TEST(lambda { SetupSMPPPD(true) }, [@READ, {}, @EXEC0], nil)
      TEST(lambda { SetupSMPPPD(false) }, [@READ, {}, @EXEC1], nil)

      nil
    end
  end
end

Yast::RuntimeClient.new.main
