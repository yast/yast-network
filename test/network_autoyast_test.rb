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
    let(:netconfig_no_eth) do
      {
        "tun" => {
          "tun0"  => {}
        },
        "tap" => {
          "tap0"  => {},
        },
        "br" => {
          "br0"   => {},
        },
        "bond" => {
          "bond0" => {}
        }
      }
    end

    it "returns empty result when both maps are empty" do
      expect(network_autoyast.merge_devices({}, {})).to be_empty
    end

    it "returns empty result when both maps are nil" do
      expect(network_autoyast.merge_devices(nil, nil)).to be_empty
    end

    it "returns other map when one map is empty" do
      expect(network_autoyast.merge_devices(netconfig_linuxrc, {})).to eql netconfig_linuxrc
      expect(network_autoyast.merge_devices({}, netconfig_ay)).to eql netconfig_ay
    end

    it "merges nonempty maps with no collisions in keys" do
      merged = network_autoyast.merge_devices(netconfig_linuxrc, netconfig_no_eth)

      expect(merged.keys).to match_array netconfig_linuxrc.keys + netconfig_no_eth.keys
    end

    it "merges nonempty maps including maps referenced by colliding key" do
      merged = network_autoyast.merge_devices(netconfig_linuxrc, netconfig_ay)

      expect(merged.keys).to match_array (netconfig_linuxrc.keys + netconfig_ay.keys).uniq
      expect(merged["eth"].keys).to match_array (netconfig_linuxrc["eth"].keys + netconfig_ay["eth"].keys).uniq
    end
  end
end
