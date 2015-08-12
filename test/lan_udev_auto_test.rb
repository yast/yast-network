#!/usr/bin/env rspec

require_relative "test_helper"

require "yast"

Yast.import "LanUdevAuto"

describe "#getDeviceName" do
  NEW_STYLE_NAME = "spec0"
  MAC_BASED_NAME = "spec-id-00:11:22:33:44:FF"
  BUS_BASED_NAME = "spec-bus-0000:00:19.0"

  LCASE_MAC_NAME = "spec-id-00:11:22:33:44:ff"

  UNKNOWN_MAC_NAME = "spec-id-00:00:00:00:00:00"
  UNKNOWN_BUS_NAME = "spec-bus-0000:00:00.0"

  INVALID_NAME = "some funny string"

  # general mocking stuff is placed here
  before(:each) do
    # mock devices configuration
    allow(Yast::LanUdevAuto).to receive(:ReadHardware) {
      [
        {
          "dev_name" => NEW_STYLE_NAME,
          "mac"      => "00:11:22:33:44:FF",
          "busid"    => "0000:00:19.0"
        }
      ]
    }
  end

  context "when new style name is provided" do
    it "returns the new style name" do
      expect(Yast::LanUdevAuto.getDeviceName(NEW_STYLE_NAME)).to be_equal NEW_STYLE_NAME
    end
  end

  context "when old fashioned mac based name is provided" do
    it "returns corresponding new style name" do
      expect(Yast::LanUdevAuto.getDeviceName(MAC_BASED_NAME)).to be_equal NEW_STYLE_NAME
    end

    it "returns same result despite of letter case in mac" do
      expect(
        Yast::LanUdevAuto.getDeviceName(LCASE_MAC_NAME)
      ).to be_equal Yast::LanUdevAuto.getDeviceName(MAC_BASED_NAME)
    end

    it "returns given name if no known device is matched" do
      expect(Yast::LanUdevAuto.getDeviceName(UNKNOWN_MAC_NAME)).to be_equal UNKNOWN_MAC_NAME
    end
  end

  context "when old fashioned bus id based name is provided" do
    it "returns corresponding new style name" do
      expect(Yast::LanUdevAuto.getDeviceName(BUS_BASED_NAME)).to be_equal NEW_STYLE_NAME
    end

    it "returns given name if no known device is matched" do
      expect(Yast::LanUdevAuto.getDeviceName(UNKNOWN_MAC_NAME)).to be_equal UNKNOWN_MAC_NAME
    end
  end

  context "when provided invalid input" do
    # TODO: should raise an exception in future
    it "returns given input" do
      expect(Yast::LanUdevAuto.getDeviceName(INVALID_NAME)).to be_equal INVALID_NAME
    end
  end
end

describe "LanUdevAuto#Write" do
  let(:attr_addr) { "ATTR{address}" }
  let(:value) { "aa:BB:cc:DD:ee:FF" }
  let(:name) { "custom-name" }


  it "writes MAC in lowercase" do
    udev_rules = [
      {
        "rule"  => attr_addr,
        "value" => value,
        "name"  => name
      }
    ]

    ay_rules = [
      format(
        "SUBSYSTEM==\"net\", ACTION==\"add\", DRIVERS==\"?*\", %s==\"%s\", NAME=\"%s\"",
        attr_addr, value.downcase, name
      )
    ]

    allow(Yast::LanUdevAuto)
      .to receive(:AllowUdevModify)
      .and_return true

    expect(Yast::SCR)
      .to receive(:Write)
      .with(path(".udev_persistent.rules"), ay_rules)
    allow(Yast::SCR)
      .to receive(:Write)
      .and_return 0

    Yast::LanUdevAuto.Import("net-udev" => udev_rules)
    Yast::LanUdevAuto.Write
  end
end

describe "LanUdevAuto#Import" do
  let(:attr_addr) { "ATTR{address}" }
  let(:value) { "aa:BB:cc:DD:ee:FF" }
  let(:name) { "custom-name" }

  it "doesn't crash when importing udev rule" do
    udev_rules = [
      {
        "rule"  => attr_addr,
        "value" => value,
        "name"  => name
      }
    ]

    expect(Yast::LanUdevAuto.Import({ "net-udev" => udev_rules }))
      .to be true
  end

  it "doesn't crash when no udev rule is defined in data for importing" do
    expect(Yast::LanUdevAuto.Import({})).to be true
  end
end
