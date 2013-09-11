#! /usr/bin/env ruby

# hwinfo is based on real hwinfo netcard output
MOCKED_ITEMS = {
  # present but unconfigured devices
  0=>{
    "hwinfo"=>{
      "name"=>"Intel Ethernet controller", 
      "type"=>"eth", 
      "udi"=>"", 
      "sysfs_id"=>"/devices/pci0000:00/0000:00:19.0", 
      "dev_name"=>"eth11", 
      "requires"=>[], 
      "modalias"=>"pci:v00008086d00001502sv000017AAsd000021F3bc02sc00i00", 
      "unique"=>"rBUF.41x4AT4gee2", 
      "driver"=>"e1000e", 
      "num"=>0, 
      "drivers"=>[
        {
          "active"=>true, 
          "modprobe"=>true, 
          "modules"=>[
            [
              "e1000e", 
              ""
            ]
          ]
        }
      ], 
      "active"=>true, 
      "module"=>"e1000e", 
      "options"=>"", 
      "bus"=>"pci", 
      "busid"=>"0000:00:19.0", 
      "mac"=>"00:01:02:03:04:05", 
      "link"=>nil, 
      "wl_channels"=>nil, 
      "wl_bitrates"=>nil, 
      "wl_auth_modes"=>nil, 
      "wl_enc_modes"=>nil
    }, 
    "udev"=>{
      "net"=>[], 
      "driver"=>""
    }
  }, 
  # devices with configuration, but not present
  1=>{"ifcfg"=>"bond0"}, 
  2=>{"ifcfg"=>"eth1"}, 
  3=>{"ifcfg"=>"br0"}, 
  4=>{"ifcfg"=>"tun0"}, 
  5=>{"ifcfg"=>"tap0"}
}

require "minitest/spec"
require "minitest/autorun"

require "yast"

Yast.import "LanItems"

describe "When querying netcard device name" do
  before do
    @lan_items = Yast::LanItems
    @lan_items.main

    # mocking only neccessary parts of Yast::LanItems so we need not to call
    # and mock inputs for Yast::LanItems.Read here
    @lan_items.Items = MOCKED_ITEMS 
  end

  it "returns empty list when querying device name with nil or empty input" do
    [ nil, [] ].each { |i| @lan_items.GetDeviceNames( i).must_be_empty }
  end

  it "can return list of device names available in the system" do
    expected_names = ["bond0", "br0", "eth1", "eth11", "tap0", "tun0"]

    @lan_items.GetNetcardNames.sort.must_equal expected_names
  end
end
