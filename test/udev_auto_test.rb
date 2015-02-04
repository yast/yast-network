#!/usr/bin/env rspec

require_relative "test_helper"

require "yast"

include Yast

Yast.import "LanUdevAuto"

describe "LanUdevAuto#Write" do
  ATTR = "ATTR{address}"
  VALUE = "aa:BB:cc:DD:ee:FF"
  NAME = "custom-name"

  it "writes MAC in lowercase" do
    udev_rules = [
      {
        "rule"  => ATTR,
        "value" => VALUE,
        "name"  => NAME
      }
    ]

    ay_rules = [
      "SUBSYSTEM==\"net\", ACTION==\"add\", DRIVERS==\"?*\", %s==\"%s\", NAME=\"%s\"" %
      [ATTR, VALUE.downcase, NAME]
    ]

    allow(Yast::LanUdevAuto)
      .to receive(:AllowUdevModify)
      .and_return true

    expect(Yast::SCR)
      .to receive(:Write)
      .with(path(".udev_persistent.rules"), ay_rules)
    expect(Yast::SCR)
      .to receive(:Write)
      .and_return 0

    LanUdevAuto.Import({ "net-udev" => udev_rules })
    LanUdevAuto.Write
  end
end
