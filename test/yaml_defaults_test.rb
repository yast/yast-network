#! /usr/bin/env rspec

require_relative "test_helper"

require "yast"

Yast.import "LanItems"

describe "LanItems#InitS390VarsByDefaults" do
  Yast.import "Arch"

  subject(:lan_items) { Yast::LanItems }

  it "sets defaults for s390 as expected" do
    allow(Yast::Arch)
      .to receive(:s390)
      .and_return(true)

    # we need to be sure that LanItems' initialization is done *now*
    # to accept arch mocking which is needed for loading reasonable
    # defaults
    lan_items.main
    lan_items.InitS390VarsByDefaults

    expect(lan_items.chan_mode).to eql "0"
    expect(lan_items.qeth_layer2).to be false
    expect(lan_items.qeth_macaddress).to eql "00:00:00:00:00:00"
    expect(lan_items.ipa_takeover).to be false
  end
end

describe "LanItems#SetDeviceVars" do
  subject(:lan_items) { Yast::LanItems }

  it "sets generic defaults as expected" do
    lan_items.SetDeviceVars({}, lan_items.instance_variable_get("@SysconfigDefaults"))

    expect(lan_items.bootproto).to eql "static"
    expect(lan_items.startmode).to eql "manual"
    expect(lan_items.ifplugd_priority).to eql "0"
    expect(lan_items.ipoib_mode).to eql "connected"
  end
end

describe "LanItems#request_firmware" do
  subject(:lan_items) { Yast::LanItems }

  it "loads module to firmware mapping properly" do
    lan_items.main

    mapping = lan_items.instance_variable_get("@request_firmware")
    expect(mapping["b43"]).to eql "b43-fwcutter"
  end
end

describe "YAML data files" do
  globs = Yast.y2paths.map { |p| "#{p}/data/**/*.yml" }
  yml_filenames = Dir.glob(globs)
  yml_filenames.each do |f|
    it "parse without error: #{f}" do
      expect { YAML.load_file(f) }.to_not raise_error
    end
  end
end
