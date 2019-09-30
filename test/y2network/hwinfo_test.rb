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
require "y2network/hwinfo"

describe Y2Network::Hwinfo do
  subject(:hwinfo) { described_class.for(interface_name) }

  let(:hardware) do
    YAML.load_file(File.join(DATA_PATH, "hardware.yml"))
  end

  let(:interface_name) { "enp1s0" }
  let(:hw_wrapper) { Y2Network::HardwareWrapper.new }

  before do
    allow(Y2Network::Hwinfo).to receive(:hwinfo_from_hardware).and_call_original
    allow(Y2Network::HardwareWrapper).to receive(:new).and_return(hw_wrapper)
    allow(Y2Network::UdevRule).to receive(:find_for).with(interface_name).and_return(udev_rule)
    allow(hw_wrapper).to receive(:ReadHardware).and_return(hardware)
  end

  let(:udev_rule) { nil }

  describe ".for" do
    context "when there is info from hardware" do
      it "returns a hwinfo object containing the info from hardware" do
        hwinfo = described_class.for(interface_name)
        expect(hwinfo.mac).to eq("52:54:00:68:54:fb")
      end
    end

    context "when there is no info from hardware" do
      let(:hardware) { [] }
      let(:udev_rule) { Y2Network::UdevRule.new_mac_based_rename(interface_name, "01:23:45:67:89:ab") }

      it "returns info from udev rules" do
        hwinfo = described_class.for(interface_name)
        expect(hwinfo.mac).to eq("01:23:45:67:89:ab")
      end

      context "when there is no info from udev rules" do
        let(:udev_rule) { nil }

        it "returns nil" do
          hwinfo = described_class.for(interface_name)
          expect(hwinfo.exists?).to eq(false)
        end
      end
    end
  end

  describe "#exists?" do
    context "when the device exists" do
      it "returns true" do
        expect(hwinfo.exists?).to eq(true)
      end
    end

    context "when the device does not exist" do
      let(:interface_name) { "missing" }

      it "returns false" do
        expect(hwinfo.exists?).to eq(false)
      end
    end
  end

  describe "#merge!" do
    subject(:hwinfo) { described_class.new(mac: "00:11:22:33:44:55:66", busid: "0000:08:00.0") }
    let(:other) { described_class.new(mac: "01:23:45:78:90:ab", dev_port: "1") }

    it "merges data from another Hwinfo object" do
      hwinfo.merge!(other)
      expect(hwinfo.mac).to eq(other.mac)
      expect(hwinfo.busid).to eq("0000:08:00.0")
      expect(hwinfo.dev_port).to eq("1")
    end
  end

  describe "#drivers" do
    it "returns the list of kernel modules names" do
      expect(hwinfo.drivers).to eq(
        [Y2Network::Driver.new("virtio_net", "")]
      )
    end
  end

  describe "#dev_port" do
    let(:interface_name) { "enp1s0" }

    before do
      allow(Yast::SCR).to receive(:Read)
        .with(Yast::Path.new(".target.string"), "/sys/class_net/#{interface_name}/dev_port")
        .and_return(raw_dev_port)
    end

    context "when the dev_port is defined" do
      let(:raw_dev_port) { "0000:08:00.0" }

      it "returns the dev_port" do
        expect(hwinfo.dev_port).to eq("0000:08:00.0")
      end
    end

    context "when the dev_port is not defined" do
      let(:raw_dev_port) { "\n" }

      it "returns the dev_port" do
        expect(hwinfo.dev_port).to be_nil
      end
    end
  end

  describe "#==" do
    context "when both objects contain the same information" do
      it "returns true" do
        expect(described_class.new("dev_name" => "eth0"))
          .to eq(described_class.new("dev_name" => "eth0"))
      end
    end

    context "when both objects contain different information" do
      it "returns false" do
        expect(described_class.new("dev_name" => "eth0"))
          .to_not eq(described_class.new("dev_name" => "eth1"))
      end
    end

    it "ignores nil values" do
      expect(described_class.new("dev_name" => "eth0", "other" => nil))
        .to eq(described_class.new("dev_name" => "eth0"))
    end
  end

  describe "#present?" do
    context "when the hardware was detected" do
      subject(:hwinfo) { described_class.new("type" => "eth") }

      it "returns true" do
        expect(hwinfo).to be_present
      end
    end

    context "when the hardware was not detected" do
      subject(:hwinfo) { described_class.new({}) }

      it "returns false" do
        expect(hwinfo).to_not be_present
      end
    end
  end

  describe "#mac" do
    before do
      allow(hwinfo).to receive(:permanent_mac).and_return(permanent_mac)
    end

    context "when the permanent MAC is defined" do
      let(:permanent_mac) { "00:11:22:33:44:55" }

      it "returns the permanent MAC" do
        expect(hwinfo.mac).to eq(hwinfo.permanent_mac)
      end
    end

    context "when the permanent MAC is empty" do
      let(:permanent_mac) { "" }

      it "returns the current MAC" do
        expect(hwinfo.mac).to eq(hwinfo.used_mac)
      end
    end

    context "when the permanent MAC is not defined" do
      let(:permanent_mac) { nil }

      it "returns the current MAC" do
        expect(hwinfo.mac).to eq(hwinfo.used_mac)
      end
    end
  end
end
