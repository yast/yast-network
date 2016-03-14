#!/usr/bin/env rspec

require_relative "test_helper"

require "yast"
require "network/install_inf_convertor"

describe "Yast::LanItemsClass" do
  subject { Yast::LanItems }

  before do
    Yast.import "LanItems"

    @ifcfg_files = SectionKeyValue.new

    # network configs
    allow(Yast::SCR).to receive(:Dir) do |path|
      case path.to_s
      when ".network.section"
        @ifcfg_files.sections
      when /^\.network\.value\."(eth\d+)"$/
        @ifcfg_files.keys(Regexp.last_match(1))
      when ".modules.options", ".etc.install_inf"
        []
      else
        raise "Unexpected Dir #{path}"
      end
    end

    allow(Yast::SCR).to receive(:Read) do |path|
      if path.to_s =~ /^\.network\.value\."(eth\d+)".(.*)/
        @ifcfg_files.get(Regexp.last_match(1), Regexp.last_match(2))
      else
        raise "Unexpected Read #{path}"
      end
    end

    allow(Yast::SCR).to receive(:Write) do |path, value|
      if path.to_s =~ /^\.network\.value\."(eth\d+)".(.*)/
        @ifcfg_files.set(Regexp.last_match(1), Regexp.last_match(2), value)
      elsif path.to_s == ".network" && value.nil?
        true
      else
        raise "Unexpected Write #{path}, #{value}"
      end
    end

    # stub NetworkInterfaces, apart from the ifcfgs
    allow(Yast::NetworkInterfaces)
      .to receive(:CleanHotplugSymlink)
    allow(Yast::NetworkInterfaces)
      .to receive(:GetTypeFromSysfs)
      .with(/eth\d+/)
      .and_return "eth"
    allow(Yast::NetworkInterfaces)
      .to receive(:GetType)
      .with(/eth\d+/)
      .and_return "eth"
    allow(Yast::NetworkInterfaces)
      .to receive(:GetType)
      .with("")
      .and_return nil
    Yast::NetworkInterfaces.instance_variable_set(:@initialized, false)

    allow(Yast::InstallInfConvertor.instance)
      .to receive(:AllowUdevModify).and_return false

    # These "expect" should be "allow", but then it does not work out,
    # because SCR multiplexes too much and the matchers get confused.

    # Hardware detection
    expect(Yast::SCR)
      .to receive(:Read)
      .with(path(".probe.netcard"))
      .and_return([])

    # miscellaneous uninteresting but hard to avoid stuff

    allow(Yast::Arch).to receive(:architecture).and_return "x86_64"
    allow(Yast::Confirm).to receive(:Detection).and_return true

    expect(Yast::SCR)
      .to receive(:Read)
      .with(path(".etc.install_inf.BrokenModules"))
      .and_return ""
    expect(Yast::SCR)
      .to receive(:Read)
      .with(path(".udev_persistent.net"))
      .and_return({})
    expect(Yast::SCR)
      .to receive(:Read)
      .with(path(".udev_persistent.drivers"))
      .and_return({})
  end

  it "does not modify DHCLIENT_SET_DEFAULT_ROUTE if not explicitly set, when editing an ifcfg" do
    @ifcfg_files.set("eth0", "STARTMODE", "auto")
    @ifcfg_files.set("eth0", "BOOTPROTO", "dhcp4")

    subject.Read
    subject.current = 0
    subject.SetItem

    subject.bootproto = "dhcp"

    subject.Commit
    subject.write

    ifcfg = Yast::NetworkInterfaces.FilterDevices("")["eth"]["eth0"]
    expect(ifcfg["DHCLIENT_SET_DEFAULT_ROUTE"]).to be_nil
  end
end
