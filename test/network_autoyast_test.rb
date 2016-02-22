#!/usr/bin/env rspec

require_relative "test_helper"

require "yast"
require "network/network_autoyast"

describe "NetworkAutoYast" do
  describe "#merge_devices" do
    let(:network_autoyast) { Yast::NetworkAutoYast.instance }
    let(:netconfig_linuxrc) do
      {
        "eth" => { "eth0" => {} }
      }
    end
    let(:netconfig_ay) do
      {
        "eth" => { "eth1" => {} }
      }
    end
    let(:netconfig_ay_colliding) do
      {
        "eth" => { "eth0" => { ifcfg_key: "value" } }
      }
    end
    let(:netconfig_no_eth) do
      {
        "tun"  => { "tun0"  => {} },
        "tap"  => { "tap0"  => {} },
        "br"   => { "br0"   => {} },
        "bond" => { "bond0" => {} }
      }
    end

    it "returns empty result when both maps are empty" do
      expect(network_autoyast.send(:merge_devices, {}, {})).to be_empty
    end

    it "returns empty result when both maps are nil" do
      expect(network_autoyast.send(:merge_devices, nil, nil)).to be_empty
    end

    it "returns other map when one map is empty" do
      expect(network_autoyast.send(:merge_devices, netconfig_linuxrc, {})).to eql netconfig_linuxrc
      expect(network_autoyast.send(:merge_devices, {}, netconfig_ay)).to eql netconfig_ay
    end

    it "merges nonempty maps with no collisions in keys" do
      merged = network_autoyast.send(:merge_devices, netconfig_linuxrc, netconfig_no_eth)

      expect(merged.keys).to match_array netconfig_linuxrc.keys + netconfig_no_eth.keys
    end

    it "merges nonempty maps including maps referenced by colliding key" do
      merged = network_autoyast.send(:merge_devices, netconfig_linuxrc, netconfig_ay)

      result_dev_types = (netconfig_linuxrc.keys + netconfig_ay.keys).uniq
      result_eth_devs  = (netconfig_linuxrc["eth"].keys + netconfig_ay["eth"].keys).uniq

      expect(merged.keys).to match_array result_dev_types
      expect(merged["eth"].keys).to match_array result_eth_devs
    end

    it "returns merged map where inner map uses values from second argument in case of collision" do
      merged = network_autoyast.send(:merge_devices, netconfig_linuxrc, netconfig_ay_colliding)

      expect(merged["eth"]).to eql netconfig_ay_colliding["eth"]
    end
  end

  describe "#merge_dns" do
    let(:instsys_dns_setup) do
      {
        "hostname"           => "instsys_hostname",
        "domain"             => "instsys_domain",
        "nameservers"        => [],
        "searchlist"         => [],
        "dhcp_hostname"      => false,
        "resolv_conf_policy" => "instsys_resolv_conf_policy",
        "write_hostname"     => false
      }
    end
    let(:ay_dns_setup) do
      {
        "hostname"           => "ay_hostname",
        "domain"             => "ay_domain",
        "nameservers"        => [],
        "searchlist"         => [],
        "dhcp_hostname"      => true,
        "resolv_conf_policy" => "ay_resolv_conf_policy"
      }
    end
    let(:network_autoyast) { Yast::NetworkAutoYast.instance }

    it "uses values from instsys, when nothing else is defined" do
      result = network_autoyast.send(:merge_dns, instsys_dns_setup, {})

      expect(result).to eql instsys_dns_setup.delete_if { |k, _v| k == "write_hostname" }
    end

    it "ignores instsys values, when AY provides ones" do
      result = network_autoyast.send(:merge_dns, instsys_dns_setup, ay_dns_setup)

      expect(result).to eql ay_dns_setup
    end
  end

  describe "#merge_routing" do
    let(:instsys_routing_setup) do
      {
        "routes"       => ["array of instsys routes"],
        "ipv4_forward" => false,
        "ipv6_forward" => false
      }
    end
    let(:ay_routing_setup) do
      {
        "routes"       => ["array of AY routes"],
        "ipv4_forward" => true,
        "ipv6_forward" => true
      }
    end
    let(:network_autoyast) { Yast::NetworkAutoYast.instance }

    it "uses values from instsys, when nothing else is defined" do
      result = network_autoyast.send(:merge_routing, instsys_routing_setup, {})

      expect(result).to eql instsys_routing_setup
    end

    it "ignores instsys values, when AY provides ones" do
      result = network_autoyast.send(:merge_routing, instsys_routing_setup, ay_routing_setup)

      expect(result).to eql ay_routing_setup
    end
  end

  describe "#merge_configs" do
    let(:network_autoyast) { Yast::NetworkAutoYast.instance }

    it "merges all necessary stuff" do
      Yast.import "UI"
      Yast::UI.as_null_object
      expect(network_autoyast).to receive(:merge_dns)
      expect(network_autoyast).to receive(:merge_routing)
      expect(network_autoyast).to receive(:merge_devices)

      network_autoyast.merge_configs("dns" => {}, "routing" => {}, "devices" => {})
    end
  end

  describe "#set_network_service" do
    Yast.import "NetworkService"
    Yast.import "Mode"

    let(:network_autoyast) { Yast::NetworkAutoYast.instance }

    before(:each) do
      allow(Yast::Mode).to receive(:autoinst).and_return(true)
    end

    def product_use_nm(nm_used)
      allow(Yast::ProductFeatures)
        .to receive(:GetStringFeature)
        .with("network", "network_manager")
        .and_return nm_used
    end

    def networking_section(net_section)
      allow(network_autoyast).to receive(:ay_networking_section).and_return(net_section)
    end

    def nm_installed(installed)
      allow(Yast::Package)
        .to receive(:Installed)
        .and_return installed
    end

    context "in SLED product" do
      before(:each) do
        product_use_nm("always")
        nm_installed(true)
        networking_section({ "managed" => true })
      end

      it "enables NetworkManager" do
        expect(Yast::NetworkService)
          .to receive(:is_backend_available)
          .with(:network_manager)
          .and_return true
        expect(Yast::NetworkService).to receive(:use_network_manager).and_return nil
        expect(Yast::NetworkService).to receive(:EnableDisableNow).and_return nil

        network_autoyast.set_network_service
      end
    end

    context "in SLES product" do
      before(:each) do
        product_use_nm("never")
        nm_installed(false)
        networking_section({})
      end

      it "enables wicked" do
        expect(Yast::NetworkService).to receive(:use_wicked).and_return nil
        expect(Yast::NetworkService).to receive(:EnableDisableNow).and_return nil

        network_autoyast.set_network_service
      end
    end
  end
end
