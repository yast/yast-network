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
        "eth4" => { "BOOTPROTO" => "none" },
        "eth5" => { "BOOTPROTO" => "none" },
        "eth6" => { "BOOTPROTO" => "dhcp" }
      },
      "bond" => {
        "bond0" => {
          "BOOTPROTO"      => "static",
          "BONDING_MASTER" => "yes",
          "BONDING_SLAVE0" => "eth1",
          "BONDING_SLAVE1" => "eth2"
        },
        "bond1" => {
          "BOOTPROTO"      => "static",
          "BONDING_MASTER" => "yes"
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

  before(:each) do
    allow(Yast::NetworkInterfaces).to receive(:Read).and_return(true)
    allow(Yast::NetworkInterfaces).to receive(:FilterDevices).with("netcard") { netconfig_items }
    allow(Yast::NetworkInterfaces).to receive(:adapt_old_config!)
    allow(Yast::NetworkInterfaces).to receive(:CleanHotplugSymlink).and_return(true)

    allow(Yast::LanItems).to receive(:ReadHardware) { hwinfo_items }

    allow(Yast::NetworkInterfaces).to receive(:devmap).and_return(nil)

    netconfig_items.each_pair do |_type, device_maps|
      device_maps.each_pair do |dev, devmap|
        allow(Yast::NetworkInterfaces)
          .to receive(:devmap)
          .with(dev)
          .and_return(devmap)
      end
    end

    Yast::LanItems.Read
  end

  describe "#GetBondableInterfaces" do
    let(:expected_bondable) { ["eth4", "eth5", "eth11", "eth12"] }
    # when converting to new API new API is used
    # for selecting bridgable devices but imports interfaces
    # from LanItems internally
    let(:bond0) { instance_double(Y2Network::Interface, name: "bond0", type: "bond") }
    let(:bond1) { instance_double(Y2Network::Interface, name: "bond1", type: "bond") }
    let(:config) { Y2Network::Config.new(source: :test) }

    context "on common architectures" do
      before(:each) do
        expect(Yast::Arch).to receive(:s390).at_least(:once).and_return false
      end

      it "returns list of slave candidates" do
        expect(config.interfaces.select_bondable(bond1).map(&:name))
          .to match_array expected_bondable
      end
    end

    context "on s390" do
      before(:each) do
        expect(Yast::Arch).to receive(:s390).at_least(:once).and_return true
      end

      it "returns list of slave candidates" do
        expect(config.interfaces).to receive(:s390_ReadQethConfig).with("eth4")
          .and_return("QETH_LAYER2" => "yes")
        expect(config.interfaces).to receive(:s390_ReadQethConfig).with(::String)
          .at_least(:once).and_return("QETH_LAYER2" => "no")

        expect(config.interfaces.select_bondable(bond1).map(&:name))
          .to match_array ["eth4"]
      end
    end
  end

  describe "#setup_bonding" do
    let(:bonding_map) { { "BONDING_SLAVE0" => "eth0", "BONDING_SLAVE1" => "enp0s3" } }
    let(:mandatory_opts) { { "BONDING_MASTER" => "yes", "BONDING_MODULE_OPTS" => option } }
    let(:option) { "bonding_option" }

    it "sets BONDING_MASTER and BONDING_MODULE_OPTS" do
      expected_map = mandatory_opts

      ret = Yast::LanItems.setup_bonding({}, [], option)

      expect(ret.select { |k, _| k !~ /BONDING_SLAVE/ }).to match(expected_map)
    end

    it "sets BONDING_SLAVEx options according to given list" do
      expected_map = bonding_map

      ret = Yast::LanItems.setup_bonding({}, ["eth0", "enp0s3"], nil)

      expect(ret.select { |k, v| k =~ /BONDING_SLAVE/ && !v.nil? }).to match expected_map
    end

    it "clears BONDING_SLAVEx which are not needed anymore" do
      expected_map = { "BONDING_SLAVE0" => "enp0s3" }

      ret = Yast::LanItems.setup_bonding(bonding_map, ["enp0s3"], nil)

      expect(ret.select { |k, v| k =~ /BONDING_SLAVE/ && !v.nil? }).to match expected_map
      # Following is required to get unneeded BONDING_SLAVEx deleted
      # during write
      expect(ret).to have_key("BONDING_SLAVE1")
      expect(ret["BONDING_SLAVE1"]).to be nil
    end

    it "clears all BONDING_SLAVESx and sets BONDING_MASTER, BONDING_OPTIONS when no slaves provided" do
      ret = Yast::LanItems.setup_bonding(bonding_map, nil, option)
      expected_slaves = { "BONDING_SLAVE0" => nil, "BONDING_SLAVE1" => nil }
      expected_map = mandatory_opts.merge(expected_slaves)

      expect(ret).to match(expected_map)
    end

    it "raises an exception in case of nil devmap" do
      expect { Yast::LanItems.setup_bonding(nil, nil, nil) }
        .to raise_error(ArgumentError, "Device map has to be provided.")
    end
  end
end
