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

  let(:parts) { [] }

  let(:udev_persistent) do
    {
      "eth0" => ["SUBSYSTEM==\"net\"", "ACTION==\"add\"", "ATTR{address}==\"?*31:78:f2\"", "NAME=\"eth0\""]
    }
  end

  before do
    allow(Yast::SCR).to receive(:Read).with(Yast::Path.new(".udev_persistent.net"))
      .and_return(udev_persistent)
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
          "ATTR{address}=\"01:23:45:67:89:ab\", NAME=\"eth0\""
      )
    end
  end

  describe ".new_bus_id_based_rename" do
    it "returns a BUS ID based renaming rule" do
      rule = described_class.new_bus_id_based_rename("eth0", "0000:08:00.0", "1")
      expect(rule.to_s).to eq(
        "SUBSYSTEM==\"net\", ACTION==\"add\", DRIVERS==\"?*\", ATTR{type}==\"1\", " \
          "KERNELS=\"0000:08:00.0\", ATTR{dev_port}=\"1\", NAME=\"eth0\""
      )
    end

    context "when the dev_port is not defined" do
      it "does not include the dev_port part" do
        rule = described_class.new_bus_id_based_rename("eth0", "0000:08:00.0")
        expect(rule.to_s).to eq(
          "SUBSYSTEM==\"net\", ACTION==\"add\", DRIVERS==\"?*\", ATTR{type}==\"1\", " \
            "KERNELS=\"0000:08:00.0\", NAME=\"eth0\""
        )
      end
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
end
