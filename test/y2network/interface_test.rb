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
require_relative "../test_helper"
require "y2network/interface"

describe Y2Network::Interface do
  subject(:interface) do
    described_class.new("eth0")
  end

  describe ".from_connection" do
    context "when the connection is virtual" do
      let(:conn) do
        Y2Network::ConnectionConfig::Bridge.new.tap { |c| c.name = "br0" }
      end

      it "returns a virtual interface" do
        interface = described_class.from_connection(conn)
        expect(interface).to be_a(Y2Network::VirtualInterface)
      end
    end

    context "when the connection is not virtual" do
      let(:conn) do
        Y2Network::ConnectionConfig::Wireless.new.tap { |c| c.name = "wlan0" }
      end

      it "returns a physical interface" do
        interface = described_class.from_connection(conn)
        expect(interface).to be_a(Y2Network::PhysicalInterface)
      end
    end
  end

  describe "#rename" do
    it "assign name to new_name parameter" do
      interface.rename("eth1", :mac)
      expect(interface.name).to eq "eth1"
    end

    it "assign renaming_mechanism to mechanism parameter" do
      interface.rename("eth1", :mac)
      expect(interface.renaming_mechanism).to eq :mac
    end

    context "if new_name differs to old one" do
      it "assign old name to old_name attribute" do
        interface.rename("eth1", :mac)
        expect(interface.old_name).to eq "eth0"
      end
    end

    context "if new_name is same as old one" do
      it "does not assign old_name attribute" do
        interface.rename("eth0", :mac)
        expect(interface.old_name).to eq nil
      end
    end
  end

  describe "#==" do
    context "given two interfaces with the same name" do
      let(:other) { Y2Network::Interface.new(interface.name) }

      it "returns true" do
        expect(interface).to eq(other)
      end
    end

    context "given two interfaces with a different name" do
      let(:other) { Y2Network::Interface.new("eth1") }

      it "returns false" do
        expect(interface).to_not eq(other)
      end
    end
  end

  describe "#modules_names" do
    let(:driver) { instance_double(Y2Network::Driver) }
    let(:hwinfo) { instance_double(Y2Network::Hwinfo, drivers: [driver]) }

    before do
      allow(interface).to receive(:hardware).and_return(hwinfo)
    end

    it "returns modules names from hardware information" do
      expect(interface.drivers).to eq([driver])
    end
  end

  describe "#update_udev_rule" do
    let(:udev_rule) { Y2Network::UdevRule.new_mac_based_rename("eth0", "01:23:45:67:89:ab") }
    let(:renaming_mechanism) { :mac }
    let(:driver) { nil }
    subject(:interface) do
      Y2Network::PhysicalInterface.new("eth0", hardware: hardware).tap do |i|
        i.renaming_mechanism = renaming_mechanism
        i.custom_driver = driver
        i.udev_rule = udev_rule
      end
    end

    let(:hardware) do
      instance_double(
        Y2Network::Hwinfo, name: "Ethernet Card 0", busid: "00:1c.0", mac: "01:23:45:67:89:ab",
        dev_port: "1", modalias: "virtio:d00000001v00001AF4"
      )
    end

    context "when the interface renaming mechanism is changed" do
      context "and the interface already has an udev rule" do
        let(:udev_rule) do
          rule = Y2Network::UdevRule.new_bus_id_based_rename("eth0", "00:1c.0", "1")
          rule.replace_part("DRIVERS", "==", "e1000e")
          rule
        end

        it "updates the udev rule parts that have changed" do
          expect(interface.udev_rule.bus_id).to eq("00:1c.0")
          interface.update_udev_rule
          expect(interface.udev_rule.mac).to eq("01:23:45:67:89:ab")
          expect(interface.udev_rule.bus_id).to be_nil
          expect(interface.udev_rule.drivers).to eq("e1000e")
        end
      end

      context "and the interface does not have an udev rule" do
        let(:udev_rule) { nil }
        let(:renaming_mechanism) { :bus_id }
        let(:new_busid_udev_rule) do
          Y2Network::UdevRule.new_bus_id_based_rename("eth0", "00:1c.0", "1")
        end

        it "assigns a new udev rule based on the selected renaming mechanism" do
          expect { interface.update_udev_rule }.to change { interface.udev_rule.to_s }
            .from("").to(new_busid_udev_rule.to_s)
        end
      end
    end
  end

  describe "#hotplug?" do
    context "when the interface does not contain hardware information" do
      subject(:interface) { Y2Network::PhysicalInterface.new("br0") }

      it "returns false" do
        expect(interface.hotplug?).to eql(false)
      end
    end

    context "when the interface contains hardware information" do
      let(:hardware) do
        Y2Network::Hwinfo.new(name: "Ethernet Connection I217-LM",
          dev_name: "enp0s25", mac: "01:23:45:67:89:ab")
      end

      subject(:interface) do
        Y2Network::PhysicalInterface.new("eth0", hardware: hardware)
      end

      context "and it is not a hotplug interface" do
        it "returns false" do
          expect(interface.hotplug?).to eql(false)
        end
      end

      context "and it is an usb hotplug interface" do
        let(:hardware) do
          Y2Network::Hwinfo.new(name: "100Mbps Network Card Adapter",
            dev_name: "enp0s20u5c2", mac: "01:23:45:67:89:ab", hotplug: "usb")
        end

        it "returns true" do
          expect(interface.hotplug?).to eql(true)
        end
      end

      context "and it is a pcmcia hotplug interface" do
        let(:hardware) do
          Y2Network::Hwinfo.new(name: "100Mbps Network Card Adapter",
            dev_name: "enp0s20u5c2", mac: "01:23:45:67:89:ab", hotplug: "pcmcia")
        end

        it "returns true" do
          expect(interface.hotplug?).to eql(true)
        end
      end
    end
  end
end
