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
require "y2network/sysconfig/interfaces_reader"
require "y2network/udev_rule_part"

describe Y2Network::Sysconfig::InterfacesReader do
  subject(:reader) { described_class.new }

  let(:netcards) { [eth0, iucv] }

  let(:eth0) do
    {
      "active" => true, "dev_name" => "eth0", "mac" => "00:12:34:56:78:90",
      "name" => "Ethernet Connection", "type" => "eth",
      "drivers" => [{ "modules" => [["virtio_net", ""]] }]
    }
  end

  let(:iucv) do
    {
      "name" => "IUCV (netiucv)", "type" => "iucv", "sysfs_id" => "/bus/iucv/devices/netiucv",
      "dev_name" => "", "modalias" => "", "unique" => "jPaU.W3A5djgRqRC", "driver" => "",
      "drivers" => [{ "active" => true, "modprobe" => true, "modules" => [["netiucv", ""]] }],
      "active" => true, "module" => "netiucv", "bus" => "iucv", "busid" => "netiucv",
      "mac" => "", "link" => nil
    }
  end

  let(:udev_rule) do
    Y2Network::UdevRule.new(
      [
        Y2Network::UdevRulePart.new("ATTR{address}", "==", "00:12:34:56:78"),
        Y2Network::UdevRulePart.new("NAME", "=", "eth0")
      ]
    )
  end

  let(:configured_interfaces) { ["lo", "eth0"] }
  let(:hardware_wrapper) { Y2Network::HardwareWrapper.new }
  let(:driver) { Y2Network::Driver.new("virtio_net") }
  let(:lszdev_output) do
    "0.0.0700:0.0.0701:0.0.0702  no   \n0.0.0800:0.0.0801:0.0.0802  yes  eth0"
  end
  let(:qeth_0700) { Y2Network::S390GroupDevice.new("qeth", "0.0.0700:0.0.0701:0.0.0702") }
  let(:qeth_0800) { Y2Network::S390GroupDevice.new("qeth", "0.0.0800:0.0.0801:0.0.0802", "eth0") }

  let(:in_s390) { false }

  TYPES = { "eth0" => "eth" }.freeze

  before do
    allow(hardware_wrapper).to receive(:ReadHardware).and_return(netcards)
    allow(Yast::Arch).to receive(:s390).and_return(in_s390)
    allow(Y2Network::HardwareWrapper).to receive(:new).and_return(hardware_wrapper)
    allow(Yast::SCR).to receive(:Dir).and_call_original
    allow(Yast::NetworkInterfaces).to receive(:GetTypeFromSysfs) { |n| TYPES[n] }
    allow(Y2Network::UdevRule).to receive(:find_for).and_return(udev_rule)
    allow(Y2Network::Driver).to receive(:from_system).and_return(driver)
    allow(Y2Network::S390GroupDevice).to receive(:all).and_return([qeth_0700, qeth_0800])
  end

  around { |e| change_scr_root(File.join(DATA_PATH, "scr_read"), &e) }

  describe "#interfaces" do

    it "reads physical interfaces" do
      interfaces = reader.interfaces
      expect(interfaces.by_name("eth0")).to_not be_nil
    end

    it "sets the renaming mechanism" do
      eth0 = reader.interfaces.by_name("eth0")
      expect(eth0.renaming_mechanism).to eq(:mac)
    end

    it "sets each interface udev rule" do
      eth0 = reader.interfaces.by_name("eth0")
      expect(eth0.udev_rule).to eq(udev_rule)
    end

    it "reads wifi interfaces"
    it "reads bridge interfaces"
    it "reads bonding interfaces"
    it "reads interfaces configuration"

    context "when a physical interface type is unknown" do
      before do
        allow(Yast::SCR).to receive(:Dir).with(Yast::Path.new(".network.section"))
          .and_return(configured_interfaces)
      end

      it "ignores that interface" do
        interfaces = reader.interfaces
        expect(interfaces.size).to eq(1)
      end
    end

    context "when a connection for a not existing device is found" do
      let(:configured_interfaces) { ["lo", "eth0", "eth1"] }

      context "and it is a virtual connection" do
        it "creates a virtual interface" do
          vlan = reader.interfaces.by_name("eth0.100")
          expect(vlan).to_not be_nil
          expect(vlan).to be_a Y2Network::VirtualInterface
        end
      end

      context "and it is not a virtual connection" do
        it "creates a not present physical interface" do
          eth1 = reader.interfaces.by_name("eth1")
          expect(eth1).to be_a Y2Network::PhysicalInterface
          expect(eth1).to_not be_present
        end
      end
    end
  end

  describe "#connections" do
    it "reads ethernet connections" do
      connections = reader.connections
      conn = connections.by_name("eth0")
      expect(conn.interface).to eq("eth0")
    end
  end

  describe "#drivers" do
    it "returns a list of drivers" do
      expect(reader.drivers).to eq([driver])
    end
  end

  describe "#s390_devices" do
    context "when running in s390 arch" do
      let(:in_s390) { true }

      it "reads s390 group devices" do
        devices = reader.s390_devices
        device = devices.by_id("0.0.0800:0.0.0801:0.0.0802")
        expect(device.interface).to eq("eth0")
      end
    end

    context "when not running in s390" do
      it "does not read the s390 group devices" do
        expect(Y2Network::S390GroupDevice).to_not receive(:all)

        reader.s390_devices
      end
    end

    it "returns a S390GroupDevicesCollection" do
      expect(reader.s390_devices).to be_a(Y2Network::S390GroupDevicesCollection)
    end
  end
end
