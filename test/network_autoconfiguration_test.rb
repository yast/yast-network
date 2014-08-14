#!/usr/bin/env rspec

require_relative "test_helper"
require_relative "factories/probe_netcard"

require "yast"
require "network/network_autoconfiguration"

Yast.import "NetworkInterfaces"

# A two level section/key => value store
# to remember values of /etc/sysconfig/network/ifcfg-*
class SectionKeyValue
  def initialize
    @sections = {}
  end

  def sections
    @sections.keys
  end

  def keys(section)
    @sections[section].keys
  end

  def get(section, key)
    @sections[section][key]
  end

  def set(section, key, value)
    section_hash = @sections[section] ||=  {}
    section_hash[key] = value
  end
end

describe Yast::NetworkAutoconfiguration do
  let(:instance) { Yast::NetworkAutoconfiguration.instance }
  let(:network_interfaces) { double("NetworkInterfaces") }

  before(:each) do
    ifcfg_files = SectionKeyValue.new

    # network configs
    allow(Yast::SCR).to receive(:Dir) do |path|
      case path.to_s
      when ".network.section"
        ifcfg_files.sections
      when /^\.network\.value\."(eth\d+)"$/
        ifcfg_files.keys($1)
      when ".modules.options", ".etc.install_inf"
        []
      else
        raise "Unexpected Dir #{path}"
      end
    end

    allow(Yast::SCR).to receive(:Read) do |path|
      if path.to_s =~ /^\.network\.value\."(eth\d+)".(.*)/
        ifcfg_files.get($1, $2)
      else
        raise "Unexpected Read #{path}"
      end
    end

    allow(Yast::SCR).to receive(:Write) do |path, value|
      if path.to_s =~ /^\.network\.value\."(eth\d+)".(.*)/
        ifcfg_files.set($1, $2, value)
      elsif path.to_s == ".network" && value.nil?
        true
      else
        raise "Unexpected Write #{path}, #{value}"
      end
    end

    # stub NetworkInterfaces, apart from the ifcfgs
    allow(Yast::NetworkInterfaces).
      to receive(:CleanHotplugSymlink)
    allow(Yast::NetworkInterfaces).
      to receive(:GetTypeFromSysfs).  with(/eth\d+/).      and_return "eth"
    allow(Yast::NetworkInterfaces).
      to receive(:GetType).           with(/eth\d+/).      and_return "eth"
    allow(Yast::NetworkInterfaces).
      to receive(:GetType).           with("").            and_return nil

    # stub program execution
    # - interfaces are up
    allow(Yast::SCR).
      to receive(:Execute).
      with(Yast::Path.new(".target.bash"), /^wicked ifstatus/).
      and_return 0
    # - reload works
    allow(Yast::SCR).
      to receive(:Execute).
      with(Yast::Path.new(".target.bash"), /^wicked ifreload/).
      and_return 0
    # - ping works
    allow(Yast::SCR).
      to receive(:Execute).
      with(Yast::Path.new(".target.bash"), /^ping/).
      and_return 0

    # These "expect" should be "allow", but then it does not work out,
    # because SCR multiplexes too much and the matchers get confused.

    # Hardware detection
    expect(Yast::SCR).
      to receive(:Read).
      with(Yast::Path.new(".probe.netcard")).
      and_return( [probe_netcard_factory(0), probe_netcard_factory(1)] )

    # link status
    expect(Yast::SCR).
      to receive(:Read).
      with(Yast::Path.new(".target.string"), %r{/sys/class/net/.*/carrier}).
      twice.
      and_return "1"

    # miscellaneous uninteresting but hard to avoid stuff

    allow(Yast::Arch).to receive(:architecture).and_return "x86_64"
    allow(Yast::Confirm).to receive(:Detection).and_return true
    expect(Yast::SCR).
      to receive(:Read).
      with(Yast::Path.new(".etc.install_inf.BrokenModules")).
      and_return ""
    expect(Yast::SCR).
      to receive(:Read).
      with(Yast::Path.new(".udev_persistent.net")).
      and_return {}
    expect(Yast::SCR).
      to receive(:Read).
      with(Yast::Path.new(".udev_persistent.drivers")).
      and_return {}
  end

  it "configures just one NIC to have a default route" do
    expect { instance.configure_dhcp }.to_not raise_error
    result = Yast::NetworkInterfaces.FilterDevices("")
    expect(result["eth"]["eth0"]["DHCLIENT_SET_DEFAULT_ROUTE"]).to eq "yes"
    expect(result["eth"]["eth1"]["DHCLIENT_SET_DEFAULT_ROUTE"]).to eq "no"
  end
end
