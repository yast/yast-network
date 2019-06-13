#!/usr/bin/env rspec

require_relative "test_helper"

require "yast"
require "network/network_autoconfiguration"

Yast.import "NetworkInterfaces"

# @return one item for a .probe.netcard list
def probe_netcard_factory(num)
  num = num.to_s
  dev_name = "eth#{num}"

  {
    "bus"           => "Virtio",
    "class_id"      => 2,
    "dev_name"      => dev_name,
    "dev_names"     => [dev_name],
    "device"        => "Ethernet Card #{num}",
    "device_id"     => 262_145,
    "driver"        => "virtio_net",
    "driver_module" => "virtio_net",
    "drivers"       => [
      {
        "active"   => true,
        "modprobe" => true,
        "modules"  => [["virtio_net", ""]]
      }
    ],
    "modalias"      => "virtio:d00000001v00001AF4",
    "model"         => "Virtio Ethernet Card #{num}",
    "resource"      => {
      "hwaddr" => [{ "addr"  => "52:54:00:5b:b2:7#{num}" }],
      "link"   => [{ "state" => true }]
    },
    "sub_class_id"  => 0,
    "sysfs_bus_id"  => "virtio#{num}",
    "sysfs_id"      => "/devices/pci0000:00/0000:00:03.0/virtio#{num}",
    "unique_key"    => "vWuh.VIRhsc57kT#{num}",
    "vendor"        => "Virtio",
    "vendor_id"     => 286_740
  }
end

describe Yast::NetworkAutoconfiguration do
  describe "it sets DHCLIENT_SET_DEFAULT_ROUTE properly" do
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
          ifcfg_files.keys(Regexp.last_match(1))
        when ".modules.options", ".etc.install_inf"
          []
        else
          raise "Unexpected Dir #{path}"
        end
      end

      allow(Yast::SCR).to receive(:Read) do |path|
        if path.to_s =~ /^\.network\.value\."(eth\d+)".(.*)/
          next ifcfg_files.get(Regexp.last_match(1), Regexp.last_match(2))
        end

        raise "Unexpected Read #{path}"
      end

      allow(Yast::SCR).to receive(:Write) do |path, value|
        if path.to_s =~ /^\.network\.value\."(eth\d+)".(.*)/
          ifcfg_files.set(Regexp.last_match(1), Regexp.last_match(2), value)
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
        .to receive(:adapt_old_config!)
      allow(Yast::NetworkInterfaces)
        .to receive(:GetTypeFromSysfs).  with(/eth\d+/).      and_return "eth"
      allow(Yast::NetworkInterfaces)
        .to receive(:GetType).           with(/eth\d+/).      and_return "eth"
      allow(Yast::NetworkInterfaces)
        .to receive(:GetType).           with("").            and_return nil
      Yast::NetworkInterfaces.instance_variable_set(:@initialized, false)

      # stub program execution
      # - interfaces are up
      allow(Yast::SCR)
        .to receive(:Execute)
        .with(path(".target.bash"), /^\/usr\/sbin\/wicked ifstatus/)
        .and_return 0
      # - reload works
      allow(Yast::SCR)
        .to receive(:Execute)
        .with(path(".target.bash"), /^\/usr\/sbin\/wicked ifreload/)
        .and_return 0
      # - ping works
      allow(Yast::SCR)
        .to receive(:Execute)
        .with(path(".target.bash"), /^\/usr\/bin\/ping/)
        .and_return 0

      # These "expect" should be "allow", but then it does not work out,
      # because SCR multiplexes too much and the matchers get confused.

      # Hardware detection
      expect(Yast::SCR)
        .to receive(:Read)
        .with(path(".probe.netcard"))
        .and_return([probe_netcard_factory(0), probe_netcard_factory(1)])

      # link status
      expect(Yast::SCR)
        .to receive(:Read)
        .with(path(".target.string"), %r{/sys/class/net/.*/carrier})
        .twice
        .and_return "1"

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
      allow(Yast::NetworkInterfaces).to receive(:Write).and_call_original
    end

    it "configures just one NIC to have a default route" do
      expect { instance.configure_dhcp }.to_not raise_error
      result = Yast::NetworkInterfaces.FilterDevices("")
      expect(result["eth"]["eth0"]["DHCLIENT_SET_DEFAULT_ROUTE"]).to eq "yes"
      expect(result["eth"]["eth1"]["DHCLIENT_SET_DEFAULT_ROUTE"]).to eq nil
    end
  end

  describe "#any_iface_active?" do
    IFACE = "eth0".freeze

    let(:instance) { Yast::NetworkAutoconfiguration.instance }

    it "returns true if any of available interfaces has configuration and is up" do
      allow(Yast::LanItems)
        .to receive(:Read)
        .and_return(true)
      allow(Yast::LanItems)
        .to receive(:GetNetcardNames)
        .and_return([IFACE, "enp0s3", "br7"])
      allow(Yast::NetworkInterfaces)
        .to receive(:adapt_old_config!)
      allow(Yast::NetworkInterfaces)
        .to receive(:Check)
        .with(IFACE)
        .and_return(true)
      allow(Yast::SCR)
        .to receive(:Execute)
        .and_return(0)

      expect(instance.any_iface_active?).to be true
    end
  end
end
