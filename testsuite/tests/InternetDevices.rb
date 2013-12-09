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

  class NetworkInterfacesClass < Module
    attr_writer :initialized
  end

  class InternetDevicesClient < Client
    def main
      Yast.include self, "testsuite.rb"

      @READ = {
        "probe"  => { "system" => [] },
        "target" => { "tmpdir" => "/tmp" }
      }

      @WRITE = {}

      @EXECUTE = {
        "target" => {
          "bash_output" => { "exit" => 0, "stderr" => "", "stdout" => "" }
        }
      }
      @EXECUTE2 = {
        "target" => {
          "bash_output" => {
            "exit"   => 0,
            "stderr" => "",
            "stdout" => "eth0\nppp0\n"
          }
        }
      }

      TESTSUITE_INIT([@READ, @WRITE, @EXECUTE], nil)

      Yast.import "Internet"
      Yast.import "InternetDevices"
      Yast.import "NetworkInterfaces"

      DUMP("Fastest")
      @READ = {
        "network"   => {
          "section" => { "dsl0" => {}, "eth0" => {} },
          "value"   => { "dsl0" => { "DEVICE" => "eth0" }, "eth0" => {} }
        },
        "sysconfig" => {
          "network" => { "config" => { "NETWORKMANAGER" => "yes" } }
        }
      }
      TEST(lambda { InternetDevices.FindFastest }, [@READ, @WRITE, @EXECUTE], nil)
      DUMP(Internet.device)
      DUMP(Internet.type)

      NetworkInterfaces.initialized = false
      Ops.set(@READ, "network", { "section" => { "dsl0" => {}, "eth0" => {} } })
      TEST(lambda { InternetDevices.FindFastest }, [@READ, @WRITE, @EXECUTE], nil)
      DUMP(Internet.device)
      DUMP(Internet.type)

      NetworkInterfaces.initialized = false
      Ops.set(@READ, "network", { "section" => { "eth1" => {}, "tr0" => {} } })
      TEST(lambda { InternetDevices.FindFastest }, [@READ, @WRITE, @EXECUTE], nil)
      DUMP(Internet.device)
      DUMP(Internet.type)

      NetworkInterfaces.initialized = false
      Ops.set(@READ, "network", { "section" => { "dsl0" => {}, "tr0" => {} } })
      TEST(lambda { InternetDevices.FindFastest }, [@READ, @WRITE, @EXECUTE], nil)
      DUMP(Internet.device)
      DUMP(Internet.type)

      NetworkInterfaces.initialized = false
      Ops.set(@READ, "network", { "section" => { "dsl0" => {}, "ppp0" => {} } })
      TEST(lambda { InternetDevices.FindFastest }, [@READ, @WRITE, @EXECUTE], nil)
      DUMP(Internet.device)
      DUMP(Internet.type)

      NetworkInterfaces.initialized = false
      Ops.set(@READ, "network", { "section" => { "ppp0" => {}, "tr1" => {} } })
      TEST(lambda { InternetDevices.FindFastest }, [@READ, @WRITE, @EXECUTE], nil)
      DUMP(Internet.device)
      DUMP(Internet.type)

      NetworkInterfaces.initialized = false
      Ops.set(@READ, "network", { "section" => { "ppp0" => {} } })
      TEST(lambda { InternetDevices.FindFastest }, [@READ, @WRITE, @EXECUTE], nil)
      DUMP(Internet.device)
      DUMP(Internet.type)

      NetworkInterfaces.initialized = false
      Ops.set(@READ, "network", { "section" => { "ippp0" => {}, "tr1" => {} } })
      TEST(lambda { InternetDevices.FindFastest }, [@READ, @WRITE, @EXECUTE], nil)
      DUMP(Internet.device)
      DUMP(Internet.type)

      NetworkInterfaces.initialized = false
      Ops.set(
        @READ,
        "network",
        { "section" => { "ippp0" => {}, "ppp0" => {} } }
      )
      TEST(lambda { InternetDevices.FindFastest }, [@READ, @WRITE, @EXECUTE], nil)
      DUMP(Internet.device)
      DUMP(Internet.type)

      NetworkInterfaces.initialized = false
      Ops.set(@READ, "network", { "section" => {} })
      TEST(lambda { InternetDevices.FindFastest }, [@READ, @WRITE, @EXECUTE], nil)
      DUMP(Internet.device)
      DUMP(Internet.type)

      NetworkInterfaces.initialized = false
      Internet.devices = nil
      Ops.set(@READ, "network", { "section" => {} })
      TEST(lambda { InternetDevices.FindFastest }, [@READ, @WRITE, @EXECUTE2], nil)
      DUMP(Internet.device)
      DUMP(Internet.type)

      nil
    end
  end
end

Yast::InternetDevicesClient.new.main
