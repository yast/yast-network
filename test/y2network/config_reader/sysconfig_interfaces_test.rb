# Copyright (c) [2019] SUSE LLC
#
# All Rights Reserved.
#
# This program is free software; you can redistribute it and/or modify it
# under the terms of version 2 of the GNU General Public License as published
# by the Free Software Foundation.
#
# This program is distributed in the hope that it will be useful, but WITHOUT
# ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or
# FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License for
# more details.
#
# You should have received a copy of the GNU General Public License along
# with this program; if not, contact SUSE LLC.
#
# To contact SUSE LLC about this file by physical or electronic mail, you may
# find current contact information at www.suse.com.

require_relative "../../test_helper"
require "y2network/config_reader/sysconfig_interfaces"

describe Y2Network::ConfigReader::SysconfigInterfaces do
  subject(:reader) { described_class.new }
  let(:netcards) do
    [eth0]
  end

  let(:eth0) do
    {
      "active" => true, "dev_name" => "eth0", "mac" => "00:12:34:56:78:90", "name" => "Ethernet Connection",
      "type" => "eth"
    }
  end

  let(:configured_interfaces) { ["lo", "eth0"] }
  TYPES = { "eth0" => "eth" }.freeze
  IFCFGS = {
    "eth0" => {
      "BOOTPROTO" => "static",
      "IPADDR"    => "192.168.1.2"
    }
  }.freeze
  SCR_PATH_REGEXP = /.network.value.\"(\w+)\".(\w+)\Z/

  before do
    allow(Yast::LanItems).to receive(:Hardware).and_return(netcards)
    allow(Yast::SCR).to receive(:Dir).with(Yast::Path.new(".network.section"))
                          .and_return(configured_interfaces)
    allow(Yast::NetworkInterfaces).to receive(:GetTypeFromSysfs) { |n| TYPES[n] }
    allow(Yast::SCR).to receive(:Read) do |path, &block|
      m = SCR_PATH_REGEXP.match(path.to_s)
      if m
        iface, key = m[1..2]
        IFCFGS[iface][key]
      else
        block.call
      end
    end
  end

  describe "#interfaces" do
    it "reads physical interfaces" do
      interfaces = reader.interfaces
      expect(interfaces.by_name("eth0")).to_not be_nil
    end

    it "reads wifi interfaces"
    it "reads bridge interfaces"
    it "reads bonding interfaces"
    it "reads interfaces configuration"
  end

  describe "#connections" do
    it "reads ethernet connections" do
      connections = reader.connections
      conn = connections.find { |i| i.interface == "eth0" }
      expect(conn.interface).to eq("eth0")
    end
  end
end
