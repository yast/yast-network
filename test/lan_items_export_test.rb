#!/usr/bin/env rspec

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

require_relative "test_helper"

require "yast"

Yast.import "LanItems"
Yast.import "Arch"

describe "LanItemsClass#export_udevs" do
  subject { Yast::LanItems }

  let(:devices) do
    {
      "eth" => {
        "eth0" => {}
      }
    }
  end

  let(:scr) { Yast::SCR }

  let(:is_s390) { false }

  let(:eth0) do
    {
      "hwinfo" => { "dev_name" => "eth0" },
      "udev"   => {
        "net" => [
          "SUBSYSTEM==\"net\"", "ACTION==\"add\"", "DRIVERS==\"?*\"", "ATTR{type}==\"1\"",
          "ATTR{address}==\"00:50:56:12:34:56\"", "NAME=\"eth0\""
        ]
      }
    }
  end

  let(:eth1) do
    {
      "hwinfo" => { "dev_name" => "eth1" },
      "udev"   => {
        "net" => [
          "SUBSYSTEM==\"net\"", "ACTION==\"add\"", "DRIVERS==\"?*\"",
          "KERNELS==\"0000:00:1f.6\"", "NAME=\"eth1\""
        ]
      }
    }
  end

  let(:items) { { 0 => eth0, 1 => eth1 } }

  before(:each) do
    # mock SCR to not touch system
    allow(scr).to receive(:Read).and_return("")
    allow(scr).to receive(:Execute).and_return("exit" => -1, "stdout" => "", "stderr" => "")
    allow(subject).to receive(:IsItemConfigured).and_return(true)
    allow(subject).to receive(:Items).and_return(items)
  end

  before(:each) do
    allow(Yast::Arch).to receive(:s390).and_return(is_s390)
  end

  it "exports udev rules" do
    ay = subject.send(:export_udevs, devices)
    expect(ay["net-udev"]).to eq(
      "eth0" => { "rule" => "ATTR{address}", "name" => "eth0", "value" => "00:50:56:12:34:56" },
      "eth1" => { "rule" => "KERNELS", "name" => "eth1", "value" => "0000:00:1f.6" }
    )
  end

  context "when an interface is not configured" do
    before do
      allow(subject).to receive(:IsItemConfigured).with(1).and_return(false)
    end

    it "does not include an udev rule for that interface" do
      ay = subject.send(:export_udevs, devices)
      expect(ay["net-udev"].keys).to eq(["eth0"])
    end
  end

  context "When running on s390" do
    let(:is_s390) { true }

    # kind of smoke test
    it "produces s390 specific content in exported AY profile" do
      allow(::File)
        .to receive(:readlink)
        .and_return("../../../qeth")

      allow(::File)
        .to receive(:read)
        .and_return("")

      ay = subject.send(:export_udevs, devices)

      expect(ay["s390-devices"]).not_to be_empty
      # check if the export builds correct map
      expect(ay["s390-devices"]["eth0"]["type"]).to eql "qeth"
    end
  end
end
