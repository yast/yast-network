#!/usr/bin/env rspec

require_relative "test_helper"

require "network/network_autoyast"
require "y2network/config_reader/sysconfig"
Yast.import "Profile"
Yast.import "Lan"

describe "NetworkAutoYast" do
  subject(:network_autoyast) { Yast::NetworkAutoYast.instance }
  let(:config) do
    Y2Network::Config.new(
      interfaces: [],
      routing:    Y2Network::Routing.new(tables: []),
      dns:        Y2Network::DNS.new,
      source:     :sysconfig
    )
  end

  before do
    allow(Yast::NetworkInterfaces).to receive(:adapt_old_config!)
    allow(Y2Network::Config).to receive(:from).and_return(double("config").as_null_object)
    allow(Yast::Lan).to receive(:Read)
    Yast::Lan.add_config(:yast, config)
  end

  describe "#merge_devices" do
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

    it "merges all necessary stuff" do
      stub_const("Yast::UI", double.as_null_object)
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
        networking_section("managed" => true)
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

  describe "#keep_net_config?" do
    let(:network_autoyast) { Yast::NetworkAutoYast.instance }

    def keep_install_network_value(value)
      allow(network_autoyast)
        .to receive(:ay_networking_section)
        .and_return(value)
    end

    it "succeedes when keep_install_network is set in AY profile" do
      keep_install_network_value("keep_install_network" => true)
      expect(network_autoyast.keep_net_config?).to be true
    end

    it "fails when keep_install_network is not set in AY profile" do
      keep_install_network_value("keep_install_network" => false)
      expect(network_autoyast.keep_net_config?).to be false
    end

    it "succeedes when keep_install_network is not present in AY profile" do
      keep_install_network_value({})
      expect(network_autoyast.keep_net_config?).to be true
    end
  end

  context "When AY profile contains old style name" do
    let(:ay_old_id) do
      {
        "interfaces" => [{ "device" => "eth-bus-0.0.1111" }]
      }
    end
    let(:ay_old_mac) do
      {
        "interfaces" => [{ "device" => "eth-id-00:11:22:33:44:55" }]
      }
    end
    let(:ay_both_vers) do
      { "interfaces" => ay_old_id["interfaces"] + [{ "device" => "eth0" }] }
    end

    describe "#createUdevFromIfaceName" do
      Yast.import "LanItems"

      subject(:lan_udev_auto) { Yast::LanItems }

      let(:ay_interfaces) { ay_both_vers["interfaces"] + ay_old_mac["interfaces"] }

      before(:each) do
        allow(Yast::LanItems).to receive(:getDeviceName).and_return("eth0")
      end

      it "returns empty list when no interfaces are provided" do
        expect(lan_udev_auto.createUdevFromIfaceName(nil)).to be_empty
        expect(lan_udev_auto.createUdevFromIfaceName([])).to be_empty
      end

      it "do not modify list of interfaces" do
        ifaces = ay_interfaces

        lan_udev_auto.send(:createUdevFromIfaceName, ay_interfaces)

        # note that this function originally filtered non old style interfaces out.
        expect(ifaces).to eql ay_interfaces
      end

      it "updates udev rules list according old style name" do
        udev_list = lan_udev_auto.send(:createUdevFromIfaceName, ay_both_vers["interfaces"])

        expect(udev_list.first["rule"]).to eql "KERNELS"
        expect(udev_list.first["value"]).to eql "0.0.1111"
        expect(udev_list.first["name"]).to eql "eth0"
      end
    end
  end

  context "When AY profile doesn't contain old style name" do
    let(:ay_only_new) do
      {
        "interfaces" => [{ "device" => "eth0" }]
      }
    end

    describe "#createUdevFromIfaceName" do
      subject(:lan_udev_auto) { Yast::LanItems }

      it "returns no udev rules" do
        ifaces = ay_only_new["interfaces"]

        expect(lan_udev_auto.send(:createUdevFromIfaceName, ifaces)).to be_empty
      end
    end
  end

  describe "#valid_rename_udev_rule?" do
    it "fails when the rule do not contain new name" do
      rule = { "rule" => "ATTR{address}", "value" => "00:02:29:69:d3:63" }
      expect(network_autoyast.send(:valid_rename_udev_rule?, rule)).to be false
      expect(network_autoyast.send(:valid_rename_udev_rule?, rule["name"] = "")).to be false
    end

    it "fails when the rule do not contain dev attribute" do
      rule = { "name" => "eth0", "value" => "00:02:29:69:d3:63" }
      expect(network_autoyast.send(:valid_rename_udev_rule?, rule)).to be false
      expect(network_autoyast.send(:valid_rename_udev_rule?, rule["rule"] = "")).to be false
    end

    it "fails when the rule do not contain dev attribute's value" do
      rule = { "name" => "eth0", "rule" => "ATTR{address}" }
      expect(network_autoyast.send(:valid_rename_udev_rule?, rule)).to be false
      expect(network_autoyast.send(:valid_rename_udev_rule?, rule["value"] = "")).to be false
    end

    it "succeedes for complete rule" do
      complete_rule = {
        "name"  => "eth0",
        "rule"  => "ATTR{address}",
        "value" => "00:02:29:69:d3:63"
      }
      expect(network_autoyast.send(:valid_rename_udev_rule?, complete_rule)).to be true
    end
  end

  describe "#rename_lan_item" do
    before(:each) do
      allow(Yast::LanItems)
        .to receive(:Items)
        .and_return(0 => { "ifcfg" => "eth0", "udev" => { "net" => ["ATTR{address}==\"24:be:05:ce:1e:91\"", "KERNEL==\"eth*\"", "NAME=\"eth0\""] } })
    end

    context "valid arguments given" do
      it "renames the item with no udev attribute change" do
        expect(Yast::LanItems)
          .to receive(:rename)
          .with("new_name")
        expect(Yast::LanItems)
          .not_to receive(:ReplaceItemUdev)

        network_autoyast.send(:rename_lan_item, 0, "new_name")
      end

      it "renames the item with udev attribute change" do
        expect(Yast::LanItems)
          .to receive(:rename)
          .with("new_name")
        expect(Yast::LanItems)
          .to receive(:ReplaceItemUdev)

        network_autoyast.send(:rename_lan_item, 0, "new_name", "KERNELS", "0000:00:03.0")
      end
    end

    context "invalid arguments given" do
      it "do not try to rename an item when missing new name" do
        expect(Yast::LanItems)
          .not_to receive(:rename)

        network_autoyast.send(:rename_lan_item, 0, nil)
        network_autoyast.send(:rename_lan_item, 0, "")
      end

      it "do not try to rename an item when given item id is invalid" do
        expect(Yast::LanItems)
          .not_to receive(:rename)

        network_autoyast.send(:rename_lan_item, nil, "new_name")
        network_autoyast.send(:rename_lan_item, -1, "new_name")
        network_autoyast.send(:rename_lan_item, 100, "new_name")
      end

      it "raise an exception when udev definition is incomplete" do
        expect do
          network_autoyast.send(:rename_lan_item, 0, "new_name", "KERNELS", nil)
        end.to raise_error(ArgumentError)
        expect do
          network_autoyast.send(:rename_lan_item, 0, "new_name", nil, "0000:00:03.0")
        end.to raise_error(ArgumentError)
      end
    end
  end

  context "When creating udev rules based on the AY profile" do
    def mock_lan_item(renamed_to: nil)
      allow(Yast::LanItems)
        .to receive(:Items)
        .and_return(
          0 => {
            "ifcfg"      => "eth0",
            "renamed_to" => renamed_to,
            "udev"       => {
              "net" => [
                "ATTR{address}==\"24:be:05:ce:1e:91\"",
                "NAME=\"#{renamed_to}\""
              ]
            }
          }
        )
    end

    describe "#assign_udevs_to_devs" do
      Yast.import "LanItems"

      let(:udev_rules) do
        [
          {
            "name"  => "eth1",
            "rule"  => "KERNELS",
            "value" => "0000:01:00.0"
          },
          {
            "name"  => "eth3",
            "rule"  => "KERNELS",
            "value" => "0000:01:00.4"
          },
          {
            "name"  => "eth0",
            "rule"  => "KERNELS",
            "value" => "0000:01:00.2"
          }
        ]
      end

      let(:persistent_udevs) do
        {
          "eth0" => [
            "KERNELS==\"0000:01:00.0\"",
            "NAME=eth0"
          ],
          "eth1" => [
            "KERNELS==\"0000:01:00.1\"",
            "NAME=eth1"
          ],
          "eth2" => [
            "KERNELS==\"0000:01:00.2\"",
            "NAME=eth2"
          ]
        }
      end

      let(:hw_netcard) do
        [
          {
            "dev_name" => "eth0",
            "busid"    => "0000:01:00.0",
            "mac"      => "00:00:00:00:00:00"
          },
          {
            "dev_name" => "eth1",
            "busid"    => "0000:01:00.1",
            "mac"      => "00:00:00:00:00:01"
          },
          {
            "dev_name" => "eth2",
            "busid"    => "0000:01:00.2",
            "mac"      => "00:00:00:00:00:02"
          }
        ]
      end

      before(:each) do
        allow(Yast::LanItems)
          .to receive(:ReadHardware)
          .with("netcard")
          .and_return(hw_netcard)
        allow(Yast::NetworkInterfaces)
          .to receive(:Read)
          .and_return(true)
        # respective agent is not able to change scr root
        allow(Yast::SCR)
          .to receive(:Read)
          .with(path(".udev_persistent.net"))
          .and_return(persistent_udevs)

        Yast::LanItems.Read
        Yast::LanItems.Items[3] = { "ifcfg" => "eth3" }
      end

      # see bnc#1056109
      # - basically dev_name is renamed_to || ifcfg || hwinfo.devname for purposes
      # of this test (ifcfg is name distinguished from sysconfig configuration,
      # hwinfo.devname is name assigned by kernel during device initialization and
      # renamed_to is new device name assigned by user when asking for device renaming
      # - updating udev rules)
      #
      # - when we have devices <eth0, eth1, eth2> and ruleset defined in AY profile
      # which renames these devices it could, before the fix, happen that after
      # applying of the ruleset we could end with new nameset e.g. <eth2, eth0, eth0>
      # which obviously leads to misconfiguration of the system
      it "applies rules so, that names remain unique" do
        network_autoyast.send(:assign_udevs_to_devs, udev_rules)

        lan_items = Yast::LanItems
        names = lan_items.Items.keys.map do |i|
          lan_items.renamed?(i) ? lan_items.renamed_to(i) : lan_items.GetDeviceName(i)
        end

        # check if device names are unique
        expect(names.sort).to eql ["eth0", "eth1", "eth2", "eth3"]
      end
    end
  end

  describe "#configure_lan" do
    before do
      allow(Yast::Profile).to receive(:current)
        .and_return("general" => general_section, "networking" => networking_section)
      allow(Yast::AutoInstall).to receive(:valid_imported_values).and_return(true)
    end

    let(:networking_section) { nil }
    let(:general_section) { nil }

    context "when second stage is disabled" do
      let(:general_section) do
        { "mode" => { "second_stage" => false } }
      end

      it "writes the Lan module configuration" do
        expect(Yast::Lan).to receive(:Write)
        subject.configure_lan
      end
    end

    context "when writing the configuration is disabled" do
      it "writes the Lan module configuration" do
        expect(Yast::Lan).to_not receive(:Write)
        subject.configure_lan(write: false)
      end
    end

    context "when second stage is enabled" do
      let(:general_section) do
        { "mode" => { "second_stage" => true } }
      end

      it "does not write the Lan module configuration" do
        expect(Yast::Lan).to_not receive(:Write)
        subject.configure_lan
      end
    end

    context "when second stage is not explicitly enabled" do
      let(:general_section) { nil }

      it "does not write the Lan module configuration" do
        expect(Yast::Lan).to_not receive(:write)
        subject.configure_lan
      end
    end

    it "merges the installation configuration" do
      expect(Yast::NetworkAutoYast.instance).to receive(:merge_configs)
      subject.configure_lan
    end

    context "when the user wants to keep the installation network" do
      let(:networking_section) { { "keep_install_network" => true } }

      it "merges the installation configuration" do
        expect(Yast::NetworkAutoYast.instance).to receive(:merge_configs)
        subject.configure_lan
      end
    end

    context "when the user does not want to keep the installation network" do
      let(:networking_section) { { "keep_install_network" => false } }

      it "does not merge the installation configuration" do
        expect(Yast::NetworkAutoYast.instance).to_not receive(:merge_configs)
        subject.configure_lan
      end
    end
  end
end
