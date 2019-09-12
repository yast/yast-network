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
require "y2network/udev_rule"

describe Y2Network::UdevRule do
  subject(:udev_rule) { described_class.new(parts) }

  before { described_class.reset_cache }

  let(:parts) { [] }

  let(:udev_persistent_net) do
    {
      "eth0" => ["SUBSYSTEM==\"net\"", "ACTION==\"add\"", "ATTR{address}==\"?*31:78:f2\"", "NAME=\"eth0\""]
    }
  end

  let(:udev_persistent_drivers) do
    {
      "virtio:d00000001v00001AF4" => ["ENV{MODALIAS}==\"virtio:d00000001v00001AF4\"", "ENV{MODALIAS}=\"e1000\""]
    }
  end

  before do
    allow(Yast::SCR).to receive(:Read).with(Yast::Path.new(".udev_persistent.net"))
      .and_return(udev_persistent_net)
    allow(Yast::SCR).to receive(:Read).with(Yast::Path.new(".udev_persistent.drivers"))
      .and_return(udev_persistent_drivers)
  end

  describe ".all" do
    it "returns the rules from :net group" do
      rules = described_class.all(:net)
      expect(rules.first.to_s).to match(/NAME=/)
    end

    it "returns the rules from :drivers group" do
      rules = described_class.all(:drivers)
      expect(rules.first.to_s).to match(/MODALIAS/)
    end
  end

  describe ".find_for" do
    it "returns the udev rule for the given device" do
      rule = described_class.find_for("eth0")
      expect(rule.to_s).to eq(
        "SUBSYSTEM==\"net\", ACTION==\"add\", ATTR{address}==\"?*31:78:f2\", NAME=\"eth0\""
      )
    end

    context "when there is no udev rule for the given device" do
      it "returns nil" do
        expect(described_class.find_for("eth1")).to be_nil
      end
    end
  end

  describe ".new_mac_based_rename" do
    it "returns a MAC based renaming rule" do
      rule = described_class.new_mac_based_rename("eth0", "01:23:45:67:89:ab")
      expect(rule.to_s).to eq(
        "SUBSYSTEM==\"net\", ACTION==\"add\", DRIVERS==\"?*\", ATTR{type}==\"1\", " \
          "ATTR{dev_id}==\"0x0\", ATTR{address}==\"01:23:45:67:89:ab\", " \
          "NAME=\"eth0\""
      )
    end
  end

  describe ".new_bus_id_based_rename" do
    it "returns a BUS ID based renaming rule" do
      rule = described_class.new_bus_id_based_rename("eth0", "0000:08:00.0", "1")
      expect(rule.to_s).to eq(
        "SUBSYSTEM==\"net\", ACTION==\"add\", DRIVERS==\"?*\", ATTR{type}==\"1\", " \
          "KERNELS==\"0000:08:00.0\", ATTR{dev_port}==\"1\", NAME=\"eth0\""
      )
    end

    context "when the dev_port is not defined" do
      it "does not include the dev_port part" do
        rule = described_class.new_bus_id_based_rename("eth0", "0000:08:00.0")
        expect(rule.to_s).to eq(
          "SUBSYSTEM==\"net\", ACTION==\"add\", DRIVERS==\"?*\", ATTR{type}==\"1\", " \
            "KERNELS==\"0000:08:00.0\", NAME=\"eth0\""
        )
      end
    end
  end

  describe ".new_driver_assignment" do
    it "returns a module assignment rule" do
      rule = described_class.new_driver_assignment("virtio:0000", "virtio_net")
      expect(rule.to_s).to eq("ENV{MODALIAS}==\"virtio:0000\", ENV{MODALIAS}=\"virtio_net\"")
    end
  end

  describe ".write_net_rules" do
    it "writes changes using the udev_persistent agent" do
      expect(Yast::SCR).to receive(:Write).with(
        Yast::Path.new(".udev_persistent.rules"), [udev_rule.to_s]
      )
      expect(Yast::SCR).to receive(:Write).with(Yast::Path.new(".udev_persistent.nil"), [])
      described_class.write_net_rules([udev_rule])
    end
  end

  describe ".write_drivers_rules" do
    let(:udev_rule) { described_class.new_driver_assignment("virtio:0000", "virtio_net") }

    it "writes changes using the udev_persistent agent" do
      expect(Yast::SCR).to receive(:Write).with(
        Yast::Path.new(".udev_persistent.drivers"), "virtio_net" => udev_rule.parts.map(&:to_s)
      )
      expect(Yast::SCR).to receive(:Write).with(Yast::Path.new(".udev_persistent.nil"), [])
      described_class.write_drivers_rules([udev_rule])
    end
  end

  describe "#add_part" do
    it "adds a new key/value to the rule" do
      udev_rule.add_part("ACTION", "==", "add")
      expect(udev_rule.parts).to eq(
        [Y2Network::UdevRulePart.new("ACTION", "==", "add")]
      )
    end
  end

  describe "#to_s" do
    let(:parts) do
      [
        Y2Network::UdevRulePart.new("ACTION", "==", "add"),
        Y2Network::UdevRulePart.new("NAME", "=", "dummy")
      ]
    end

    it "returns the string representation for the rules file" do
      expect(udev_rule.to_s).to eq(
        'ACTION=="add", NAME="dummy"'
      )
    end
  end

  describe "#mac" do
    subject(:udev_rule) { described_class.new_mac_based_rename("eth0", "01:23:45:67:89:ab") }

    it "returns the MAC from the udev rule" do
      expect(udev_rule.mac).to eq("01:23:45:67:89:ab")
    end

    context "if no MAC address is present" do
      subject(:udev_rule) { described_class.new }

      it "returns nil" do
        expect(udev_rule.mac).to be_nil
      end
    end
  end

  describe "#bus_id" do
    subject(:udev_rule) { described_class.new_bus_id_based_rename("eth0", "0000:08:00.0") }

    it "returns the BUS ID from the udev rule" do
      expect(udev_rule.bus_id).to eq("0000:08:00.0")
    end

    context "if no BUS ID is present" do
      subject(:udev_rule) { described_class.new }

      it "returns nil" do
        expect(udev_rule.bus_id).to be_nil
      end
    end
  end

  describe "#dev_port" do
    subject(:udev_rule) { described_class.new_bus_id_based_rename("eth0", "0000:08:00.0", "1") }

    it "returns the device port from the udev rule" do
      expect(udev_rule.dev_port).to eq("1")
    end

    context "if no device port is present" do
      subject(:udev_rule) { described_class.new }

      it "returns nil" do
        expect(udev_rule.dev_port).to be_nil
      end
    end
  end

  describe "#device" do
    subject(:udev_rule) { described_class.new_mac_based_rename("eth0", "01:23:45:67:89:ab") }

    it "returns device" do
      expect(udev_rule.device).to eq("eth0")
    end
  end

  describe "#original_modalias" do
    subject(:udev_rule) { described_class.new_driver_assignment("virtio:0000", "virtio_net") }

    it "returns the original modalias" do
      expect(udev_rule.original_modalias).to eq("virtio:0000")
    end
  end

  describe "#driver" do
    subject(:udev_rule) { described_class.new_driver_assignment("virtio:0000", "virtio_net") }

    it "return the assigned driver" do
      expect(udev_rule.driver).to eq("virtio_net")
    end
  end
end
