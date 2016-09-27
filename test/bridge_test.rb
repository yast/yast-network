#! /usr/bin/env rspec

require_relative "test_helper"

require "yast"

Yast.import "LanItems"

describe Yast::LanItems do
  let(:netconfig_items) do
    {
      "eth"  => {
        "eth1" => { "BOOTPROTO" => "none" },
        "eth2" => { "BOOTPROTO" => "none" },
        "eth4" => {
          "BOOTPROTO" => "static",
          "IPADDR"    => "0.0.0.0",
          "PREFIX"    => "32"
        },
        "eth5" => { "BOOTPROTO" => "static", "STARTMODE" => "nfsroot" },
        "eth6" => { "BOOTPROTO" => "static", "STARTMODE" => "ifplugd" }
      },
      "tun"  => {
        "tun0" => {
          "BOOTPROTO" => "static",
          "STARTMODE" => "onboot",
          "TUNNEL"    => "tun"
        }
      },
      "tap"  => {
        "tap0" => {
          "BOOTPROTO" => "static",
          "STARTMODE" => "onboot",
          "TUNNEL"    => "tap"
        }
      },
      "br"   => {
        "br0" => { "BOOTPROTO" => "dhcp" }
      },
      "bond" => {
        "bond0" => {
          "BOOTPROTO"      => "static",
          "BONDING_MASTER" => "yes",
          "BONDING_SLAVE0" => "eth1",
          "BONDING_SLAVE1" => "eth2"
        }
      }
    }
  end

  let(:hwinfo_items) do
    [
      { "dev_name" => "eth11" },
      { "dev_name" => "eth12" }
    ]
  end

  let(:expected_bridgeable) do
    [
      "bond0",
      "eth4",
      "eth11",
      "eth12",
      "tap0"
    ]
  end

  before(:each) do
    allow(Yast::NetworkInterfaces).to receive(:FilterDevices).with("netcard") { netconfig_items }

    allow(Yast::LanItems).to receive(:ReadHardware) { hwinfo_items }

    Yast::LanItems.Read
  end

  describe "#GetBridgeableInterfaces" do
    before(:each) do
      # FindAndSelect initializes internal state of LanItems it
      # is used internally by some helpers
      Yast::LanItems.FindAndSelect("br0")
    end

    it "returns list of slave candidates" do
      expect(
        Yast::LanItems
          .GetBridgeableInterfaces(Yast::LanItems.GetCurrentName)
          .map { |i| Yast::LanItems.GetDeviceName(i) }
      ).to match_array expected_bridgeable
    end
  end

  describe "#old_bridge_port_config?" do
    before do
      allow(Yast::NetworkInterfaces).to receive(:FilterDevices).with("") { netconfig_items }
    end

    it "returns false if the interface is not configured" do
      allow(Yast::NetworkInterfaces).to receive(:FilterDevices).with("") { {} }

      expect(Yast::LanItems.old_bridge_port_config?("eth0")).to eql(false)
    end

    it "returns true if given interface bootproto is static and IP is 0.0.0.0" do
      expect(Yast::LanItems.old_bridge_port_config?("eth4")).to eql(true)
    end
  end

  describe "#bridge_ip" do

    it "returns an empty string if no IP is given" do
      expect(Yast::LanItems.bridge_ip(nil)).to eql("")
    end

    it "returns an empty string if given IP is 0.0.0.0" do
      expect(Yast::LanItems.bridge_ip("0.0.0.0")).to eql("")
    end

    it "returns given IP if it is not 0.0.0.0" do
      expect(Yast::LanItems.bridge_ip("192.168.0.120")).to eql("192.168.0.120")
    end

  end

  describe "#adapt_bridge_port_config?" do
    it "returns false if no given ports" do
      expect(Yast::LanItems.adapt_bridge_port_config?(nil)).to eql(false)
      expect(Yast::LanItems.adapt_bridge_port_config?([])).to eql(false)
    end

    it "asks the user if he wants to adapt the bridge port config for given ports" do
      expect(Yast::Popup).to receive(:YesNoHeadline).and_return(true)

      expect(Yast::LanItems.adapt_bridge_port_config?(["eth0"])).to eql(true)
    end
  end

  describe "#adapt_bridge_port_config!" do
    let(:eth1) do
      {
        "IPADDR"    => "172.26.0.1",
        "NETMASK"   => "255.255.255.0",
        "PREFIXLEN" => "24"
      }
    end

    before do
      allow(Yast::LanItems).to receive(:get_configured).with("eth1").and_return(1)
      allow(Yast::LanItems).to receive(:get_configured).with("eth2").and_return(-1)
      allow(Yast::LanItems).to receive(:GetDeviceMap).with(1).and_return(eth1)
      allow(Yast::LanItems).to receive(:GetDeviceMap).with(-1).and_return(nil)
    end

    it "returns false if the given interface is not configured" do
      expect(Yast::LanItems).not_to receive(:SetDeviceMap)
      expect(Yast::LanItems.adapt_bridge_port_config!("eth2")).to eql(false)
    end

    it "empties the IPADDR, NETMASK and PREFIXLEN of the given interface" do
      expect(Yast::LanItems).to receive(:SetDeviceMap)
        .with(1, "IPADDR" => "", "NETMASK" => "", "PREFIXLEN" => "", "BOOTPROTO" => "none")

      Yast::LanItems.adapt_bridge_port_config!("eth1")
    end

    it "returns true when adapted" do
      allow(Yast::LanItems).to receive(:SetDeviceMap)

      expect(Yast::LanItems.adapt_bridge_port_config!("eth1")).to eql(true)
    end

  end
end
