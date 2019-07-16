#!/usr/bin/env rspec

require_relative "test_helper"
require "network/lan_items_summary"
require "y2network/interfaces/br_interface"

Yast.import "LanItems"

describe Yast::LanItemsSummary do
  MULTIPLE_INTERFACES = N_("Multiple Interfaces")

  let(:dhcp_maps) do
    [
      { "BOOTPROTO" => "dhcp" },
      { "BOOTPROTO" => "none" },
      { "BOOTPROTO"    => "static",
        "IPADDR"       => "1.2.3.4",
        "NETMASK"      => "255.255.255.0",
        "BRIDGE_PORTS" => "eth1" }
    ].freeze
  end

  let(:items) do
    {
      0 => { "ifcfg" => "eth0" },
      1 => { "ifcfg" => "eth1" },
      2 => { "ifcfg" => "br0" }
    }.freeze
  end

  let(:interfaces) {}

  before do
    allow(Yast::LanItems).to receive(:Items).and_return(items)
    allow(Yast::LanItems).to receive(:IsItemConfigured).and_return(true)
    allow(Yast::NetworkInterfaces).to receive(:FilterDevices).with("netcard").and_return("br" => { "br0" => dhcp_maps[2] })
    dhcp_maps.each_with_index do |item, index|
      allow(Yast::LanItems).to receive(:GetDeviceMap).with(index).and_return(item)
    end

    allow(Y2Network::Config)
      .to receive(:find)
      .and_return(instance_double(Y2Network::Config, interfaces: interfaces))
  end

  describe "#default" do
    it "returns a Richtext summary of the configured interfaces" do
      expect(subject.default)
        .to eql "<ul>" \
                "<li><p>eth0<br>DHCP</p></li>" \
                "<li><p>eth1<br>NONE</p></li>" \
                "<li><p>br0<br>STATIC</p></li>" \
                "</ul>"
    end

    it "returns Summary.NotConfigured in case of not configured interfaces" do
      allow(Yast::LanItems).to receive(:IsItemConfigured).and_return(false)

      expect(subject.default).to eql Yast::Summary.NotConfigured
    end
  end

  describe "#proposal" do
    let(:interfaces) { instance_double(Y2Network::InterfacesCollection) }
    let(:eth1) { instance_double(Y2Network::Interface, name: "eth1") }
    let(:slaves_collection) { instance_double(Y2Network::InterfacesCollection, to_a: [eth1]) }
    let(:br0) do
      instance_double(
        Y2Network::Interfaces::BrInterface,
        name:   "br0",
        type:   Y2Network::InterfaceType::BRIDGE,
        slaves: slaves_collection
      )
    end

    it "returns a Richtext summary of the configured interfaces" do
      allow(interfaces).to receive(:by_type).and_return([])
      allow(interfaces).to receive(:by_type).with(Y2Network::InterfaceType::BRIDGE).and_return([br0])

      expect(subject.proposal)
        .to eql "<ul>" \
                "<li>Configured with DHCP: eth0</li>" \
                "<li>Statically configured: br0</li>" \
                "<li>Bridges: br0 (eth1)</li>" \
                "</ul>"
    end

    it "returns Summary.NotConfigured in case of not configured interfaces" do
      allow(Yast::LanItems).to receive(:find_dhcp_ifaces).and_return([])
      allow(Yast::LanItems).to receive(:find_static_ifaces).and_return([])
      allow(interfaces).to receive(:by_type).and_return([])

      expect(subject.proposal).to eql Yast::Summary.NotConfigured
    end
  end

  describe "#one_line" do
    it "returns a plain text summary of the configured interfaces in one line" do
      expect(subject.one_line).to eql(MULTIPLE_INTERFACES)
    end

    context "when there are no configured interfaces" do
      let(:items) { {} }
      it "returns Summary.NotConfigured" do
        expect(subject.one_line).to eql(Yast::Summary.NotConfigured)
      end
    end

    context "when there is only one configured interface" do
      let(:items) { { 0 => { "ifcfg" => "eth0" } } }

      it "returns the interface bootproto and interface name" do
        expect(subject.one_line).to eql "DHCP / eth0"
      end
    end

    context "when there are multiple interfaces" do
      let(:items) { { 0 => { "ifcfg" => "eth0" }, 1 => { "ifcfg" => "eth1" } } }

      context "sharing the same bootproto" do
        let(:dhcp_maps) { [{ "BOOTPROTO" => "dhcp" }, { "BOOTPROTO" => "dhcp" }] }

        it "returns the bootproto and 'Multiple Interfaces'" do
          expect(subject.one_line).to eql("DHCP / #{MULTIPLE_INTERFACES}")
        end
      end

      context "with different bootproto" do
        let(:dhcp_maps) { [{ "BOOTPROTO" => "DHCP" }, { "IPADDR" => "1.2.3.4" }] }

        it "returns 'Multiple Interfaces'" do
          expect(subject.one_line).to eql(MULTIPLE_INTERFACES)
        end
      end
    end
  end
end
