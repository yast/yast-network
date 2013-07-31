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
  class BondClient < Client
    def main
      Yast.import "Assert"
      Yast.import "Testsuite"

      @READ = {
        "network"   => {
          "section" => {
            "eth1"  => nil,
            "eth2"  => nil,
            "eth4"  => nil,
            "eth5"  => nil,
            "eth6"  => nil,
            "bond0" => nil,
            "bond1" => nil
          },
          "value"   => {
            "eth1"  => { "BOOTPROTO" => "none" },
            "eth2"  => { "BOOTPROTO" => "none" },
            "eth4"  => { "BOOTPROTO" => "none" },
            "eth5"  => { "BOOTPROTO" => "none" },
            "eth6"  => { "BOOTPROTO" => "dhcp" },
            "bond0" => {
              "BOOTPROTO"      => "static",
              "BONDING_MASTER" => "yes",
              "BONDING_SLAVE0" => "eth1",
              "BONDING_SLAVE1" => "eth2"
            },
            "bond1" => { "BOOTPROTO" => "static", "BONDING_MASTER" => "yes" }
          }
        },
        "probe"     => {
          "architecture" => "i386",
          "netcard"      => [
            # yast2-network lists those as "Not configured" devices (no matching ifcfg files are defined)
            {
              "bus"            => "PCI",
              "bus_hwcfg"      => "pci",
              "class_id"       => 2,
              "dev_name"       => "eth11",
              "dev_names"      => ["eth11"],
              "device_id"      => 70914,
              "driver"         => "e1000e",
              "driver_module"  => "e1000e",
              "drivers"        => [
                {
                  "active"   => true,
                  "modprobe" => true,
                  "modules"  => [["e1000e", ""]]
                }
              ],
              "modalias"       => "pci:v00008086d00001502sv000017AAsd000021F3bc02sc00i00",
              "model"          => "Intel Ethernet controller",
              "old_unique_key" => "wH9Z.41x4AT4gee2",
              "resource"       => {
                "hwaddr" => [{ "addr" => "00:01:02:03:04:05" }],
                "io"     => [
                  {
                    "active" => true,
                    "length" => 32,
                    "mode"   => "rw",
                    "start"  => 24704
                  }
                ],
                "irq"    => [{ "count" => 0, "enabled" => true, "irq" => 20 }],
                "mem"    => [
                  {
                    "active" => true,
                    "length" => 131072,
                    "start"  => 4087349248
                  },
                  { "active" => true, "length" => 4096, "start" => 4087590912 }
                ]
              },
              "rev"            => "4",
              "slot_id"        => 25,
              "sub_class_id"   => 0,
              "sub_device_id"  => 74227,
              "sub_vendor"     => "Vendor",
              "sub_vendor_id"  => 7,
              "sysfs_bus_id"   => "0000:00:19.0",
              "sysfs_id"       => "/devices/pci0000:00/0000:00:19.0",
              "unique_key"     => "rBUF.41x4AT4gee2",
              "vendor"         => "Intel Corporation",
              "vendor_id"      => 98438
            },
            {
              "bus"            => "PCI",
              "bus_hwcfg"      => "pci",
              "class_id"       => 2,
              "dev_name"       => "eth12",
              "dev_names"      => ["eth12"],
              "device_id"      => 70914,
              "driver"         => "e1000e",
              "driver_module"  => "e1000e",
              "drivers"        => [
                {
                  "active"   => true,
                  "modprobe" => true,
                  "modules"  => [["e1000e", ""]]
                }
              ],
              "modalias"       => "pci:v00008086d00001502sv000017AAsd000021F3bc02sc00i00",
              "model"          => "Intel Ethernet controller",
              "old_unique_key" => "wH9Z.41x4AT4gee2",
              "resource"       => {
                "hwaddr" => [{ "addr" => "00:11:12:13:14:15" }],
                "io"     => [
                  {
                    "active" => true,
                    "length" => 32,
                    "mode"   => "rw",
                    "start"  => 24704
                  }
                ],
                "irq"    => [{ "count" => 0, "enabled" => true, "irq" => 20 }],
                "mem"    => [
                  {
                    "active" => true,
                    "length" => 131072,
                    "start"  => 4087349248
                  },
                  { "active" => true, "length" => 4096, "start" => 4087590912 }
                ]
              },
              "rev"            => "4",
              "slot_id"        => 25,
              "sub_class_id"   => 0,
              "sub_device_id"  => 74227,
              "sub_vendor"     => "Vendor",
              "sub_vendor_id"  => 7,
              "sysfs_bus_id"   => "0000:00:19.0",
              "sysfs_id"       => "/devices/pci0000:00/0000:00:19.0",
              "unique_key"     => "rBUF.41x4AT4gee2",
              "vendor"         => "Intel Corporation",
              "vendor_id"      => 98438
            }
          ]
        },
        "sysconfig" => { "console" => { "CONSOLE_ENCODING" => "UTF-8" } }
      }

      @EXEC = {
        "target" => {
          "bash_output" => {
            "exit"   => 0,
            "stdout" => "charset=UTF-8",
            "stderr" => ""
          }
        }
      }

      Testsuite.Init([@READ, {}, @EXEC], nil)

      Yast.import "NetworkInterfaces"
      Yast.import "LanItems"

      Testsuite.Test(LanItems.Read, [@READ, {}, @EXEC], nil)

      Testsuite.Dump("LanItems::BuildBondIndex")
      @expected_bond_index = { "eth1" => "bond0", "eth2" => "bond0" }
      Assert.Equal(@expected_bond_index, LanItems.BuildBondIndex)

      Testsuite.Dump("LanItems::GetBondSlaves")
      @expected_bond_slaves = ["eth1", "eth2"]
      Assert.Equal(@expected_bond_slaves, LanItems.GetBondSlaves("bond0"))

      @expected_bond_slaves = []
      Assert.Equal(@expected_bond_slaves, LanItems.GetBondSlaves("bond1"))

      Testsuite.Dump("LanItems::GetBondableInterfaces")
      @expected_bondable = ["eth11", "eth12", "eth4", "eth5"]
      @bondable_devs = []

      # query bondable devices and make testsuite independent of internal sorting of LanItems
      Assert.Equal(true, LanItems.FindAndSelect("bond1")) # set up context for GetBondableInterfaces

      @bondable_devs = Builtins.maplist(
        LanItems.GetBondableInterfaces(LanItems.GetCurrentName)
      ) { |itemId| LanItems.GetDeviceName(itemId) }
      @bondable_devs = Builtins.sort(@bondable_devs)

      Assert.Equal(@expected_bondable, @bondable_devs)

      nil
    end
  end
end

Yast::BondClient.new.main
