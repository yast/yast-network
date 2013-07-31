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
  class HostClient < Client
    def main
      Yast.include self, "testsuite.rb"

      @READ = {
        "target" => { "size" => 1, "tmpdir" => "/tmp" },
        "etc"    => {
          "hosts" => {
            "127.0.0.1"  => ["localhost localhost.localdomain"],
            "10.20.1.29" => ["beholder"]
          }
        }
      }

      TESTSUITE_INIT([@READ], nil)

      Yast.import "Host"
      Yast.import "Progress"
      Progress.off

      DUMP("Read")
      TEST(lambda { Host.Read }, [@READ], nil)

      DUMP("Write")
      #TEST(``(Host::Write()), [], nil);

      @lan_settings = {
        "dns"        => {
          "dhcp_hostname" => false,
          "domain"        => "suse.com",
          "hostname"      => "nashif",
          "nameservers"   => ["10.0.0.1"],
          "searchlist"    => ["suse.com"]
        },
        "interfaces" => [
          {
            "STARTMODE" => "onboot",
            "BOOTPROTO" => "static",
            "BROADCAST" => "10.10.1.255",
            "IPADDR"    => "10.10.1.1",
            "NETMASK"   => "255.255.255.0",
            "NETWORK"   => "10.10.1.0",
            "UNIQUE"    => "",
            "device"    => "eth0",
            "module"    => "",
            "options"   => ""
          }
        ],
        "routing"    => {
          "routes"        => [
            {
              "destination" => "default",
              "device"      => "",
              "gateway"     => "10.10.0.8",
              "netmask"     => "0.0.0.0"
            }
          ],
          "ip_forwarding" => false
        }
      }

      DUMP("Import")
      #TEST(``(Host::Import(lan_settings)), [], nil);

      DUMP("Export")
      TEST(lambda { Host.Export }, [], nil)

      nil
    end
  end
end

Yast::HostClient.new.main
