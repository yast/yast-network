#! /usr/bin/env rspec

require_relative "test_helper"

require "yast"

Yast.import "YaPI::NETWORK"
Yast.import "NetworkInterfaces"
Yast.import "Routing"
Yast.import "IP"
Yast.import "Service"
Yast.import "DNS"
Yast.import "LanItems"

describe Yast::YaPI::NETWORK do
  include YaPINetworkStub

  describe ".Write" do

    context "with routes" do
      # Mock the system to do not break anything
      before do
        allow(Yast::Routing).to receive(:Read)
        allow(Yast::Routing).to receive(:Routes)
        allow(Yast::Routing).to receive(:Write)
      end

      subject { Yast::YaPI::NETWORK.Write("route" => route) }

      let(:success) { { "error" => "", "exit" => "0" } }

      context "with no gateway in the default route" do
        let(:route) { { "default" => nil } }

        it "returns success" do
          expect(subject).to eq success
        end

        it "empties the routes" do
          expect(Yast::Routing).to receive(:Routes=).with []
          subject
        end
      end

      context "with empty gateway in the default  route" do
        let(:route) { { "default" => { "via" => "" } } }

        it "returns success" do
          expect(subject).to eq success
        end

        it "empties the routes" do
          expect(Yast::Routing).to receive(:Routes=).with []
          subject
        end
      end

      context "with a gateway in the default route" do
        let(:route) { { "default" => { "via" => "TheIP" } } }
        before do
          expect(Yast::IP).to receive(:Check4).with("TheIP").and_return valid
        end

        context "if it's a valid IP4" do
          let(:valid) { true }

          it "returns success" do
            expect(subject).to eq success
          end

          it "correctly modifies the routes" do
            expect(Yast::Routing).to receive(:Routes=).with(
              [
                {
                  "destination" => "default",
                  "gateway"     => "TheIP",
                  "netmask"     => "-",
                  "device"      => "-"
                }
              ]
            )
            subject
          end
        end

        context "if it's not a valid IP4" do
          let(:valid) { false }

          it "returns failure" do
            res = subject
            expect(res["exit"]).to eq "-1"
            expect(res["error"]).to_not be_empty
          end

          it "doesnt't modify the routes" do
            expect(Yast::Routing).to_not receive(:Routes=)
            subject
          end
        end
      end
    end

    context "with interfaces" do

      subject { Yast::YaPI::NETWORK.Write("interface" => interface) }

      before do
        interface.keys.map do |k|
          stub_clean_cache(k)
        end
      end

      context("setting bootproto and startmode") do
        let(:interface) { { "eth0" => { "bootproto" => "dhcp6", "startmode" => "onboot" } } }

        it "sets both parameters correctly" do
          expect(Yast::NetworkInterfaces).to receive(:Current=).with(
            "BOOTPROTO" => "dhcp6",
            "STARTMODE" => "onboot"
          )
          stub_write_interfaces
          subject
        end
      end

      context("setting IP address and netmask") do
        let(:interface) { { "eth0" => { "ipaddr" => "TheIP/#{netmask}" } } }

        context("with valid netmask in dot notation") do
          let(:netmask) { "255.255.255.0" }

          it "converts netmask to CIDR" do
            expect(Yast::NetworkInterfaces).to receive(:Current=).with(
              "BOOTPROTO" => "static",
              "STARTMODE" => "auto",
              "IPADDR"    => "TheIP/24"
            )
            stub_write_interfaces
            subject
          end
        end

        context("with valid netmask in CIDR notation") do
          let(:netmask) { "16" }

          it "keeps netmask untouched" do
            expect(Yast::NetworkInterfaces).to receive(:Current=).with(
              "BOOTPROTO" => "static",
              "STARTMODE" => "auto",
              "IPADDR"    => "TheIP/#{netmask}"
            )
            stub_write_interfaces
            subject
          end
        end

      end

      context "setting vlan_id and vlan_etherdevice" do
        let(:interface) do
          {
            "eth5.23" => {
              "bootproto"        => "static",
              "ipaddr"           => "1.2.3.8/24",
              "vlan_etherdevice" => "eth5",
              "vlan_id"          => "42"
            }
          }
        end

        it "sets both parameters correctly" do
          expect(Yast::NetworkInterfaces).to receive(:Current=).with(
            "BOOTPROTO"   => "static",
            "STARTMODE"   => "auto",
            "IPADDR"      => "1.2.3.8/24",
            "ETHERDEVICE" => "eth5",
            "VLAN_ID"     => "42"
          )
          stub_write_interfaces
          subject
        end
      end

      context("setting a bond interface with required parameters") do
        let(:interface) { { "bond0" => { "bond" => "yes", "bond_slaves" => "eth1" } } }

        it "sets default values" do
          expect(Yast::NetworkInterfaces).to receive(:Current=).with(
            "BOOTPROTO"           => "static",
            "STARTMODE"           => "auto",
            "BONDING_MASTER"      => "yes",
            "BONDING_MODULE_OPTS" => nil,
            "BONDING_SLAVE0"      => "eth1"
          )
          stub_write_interfaces
          subject
        end
      end

      context("setting a bond interface with extra parameters") do
        let(:interface) do
          {
            "bond0" => {
              "bond"        => "yes",
              "bond_slaves" => "eth1 eth4 eth5",
              "bond_option" => "mode=active-backup miimon=100"
            }
          }
        end

        it "sets extra parameters correctly" do
          expect(Yast::NetworkInterfaces).to receive(:Current=).with(
            "BOOTPROTO"           => "static",
            "STARTMODE"           => "auto",
            "BONDING_MASTER"      => "yes",
            "BONDING_MODULE_OPTS" => "mode=active-backup miimon=100",
            "BONDING_SLAVE0"      => "eth1",
            "BONDING_SLAVE1"      => "eth4",
            "BONDING_SLAVE2"      => "eth5"
          )
          stub_write_interfaces
          subject
        end

      end

    end

  end

  # FIXME: Interfaces parsing still pending
  describe ".Read" do
    let(:attributes) do
      {
        startmode: "manual",
        bootproto: "static",
        ipaddr:    "TheIP",
        prefix:    "24",
        mtu:       "1234"
      }.merge(context_attributes)
    end

    before do
      stub_network_reads
      allow(Yast::Routing).to receive(:GetGateway).and_return "TheIP"
      allow(Yast::Hostname).to receive(:CurrentHostname).and_return "Hostname"
      allow(Yast::Hostname).to receive(:CurrentDomain).and_return "TheDomain"
      allow(Yast::DNS).to receive(:dhcp_hostname).and_return "Hostname"
      allow(Yast::DNS).to receive(:nameservers).and_return []
      allow(Yast::DNS).to receive(:searchlist).and_return ["suse.com"]
    end

    subject { Yast::YaPI::NETWORK.Read }

    let(:config) do
      {
        "routes"   => {
          "default"       => {
            "via" => "TheIP"
          }
        },
        "dns"      => {
          "nameservers" => [],
          "searches"    => ["suse.com"]
        },
        "hostname" => {
          "name"          => "Hostname",
          "domain"        => "TheDomain",
          "dhcp_hostname" => "Hostname"
        }
      }.merge(interfaces)
    end

    context "with no interfaces"do
      let(:interfaces) do
        {
          "interfaces" => {}
        }
      end

      it "returns the correct hash" do
        expect(Yast::YaPI::NETWORK.Read).to eql(config)
        subject
      end
    end

    context "with a vlan interface" do
      let(:context_attributes) do
        {
          type:             "vlan",
          vlan_id:          "42",
          vlan_etherdevice: "eth5"
        }
      end

      let(:interfaces) do
        {
          "interfaces" => {
            "eth5.23" => {
              "startmode"        => "manual",
              "bootproto"        => "static",
              "ipaddr"           => "TheIP/24",
              "mtu"              => "1234",
              "vlan_id"          => "42",
              "vlan_etherdevice" => "eth5",
              "vendor"           => "eth5.23"
            }
          }
        }
      end

      before do
        allow(Yast::LanItems).to receive(:Items).with(no_args).and_return("0" => { "ifcfg" => "eth5.23" })
        allow(Yast::LanItems).to receive(:GetCurrentName).and_return("eth5.23")
        allow(Yast::LanItems).to receive(:getCurrentItem).and_return(
          "hwinfo" => { "dev_name" => "eth5.23", "type" => "eth", "name" => "eth5.23" }
        )
        allow(Yast::LanItems).to receive(:IsCurrentConfigured).and_return(true)
        attributes.map do |k, v|
          allow(Yast::LanItems).to receive(k) { v }
        end
        allow(Yast::LanItems).to receive(:SetItem)
      end

      it "returns the correct hash" do
        expect(subject).to eql(config)
      end
    end

    context "with a bond interface" do
      let(:context_attributes) do
        {
          "type"        => "bond",
          "bond_slaves" => ["eth1", "eth2", "eth3"],
          "bond_option" => "mode=active-backup miimon=100"
        }
      end

      let(:interfaces) do
        {
          "interfaces" => {
            "bond0" => {
              "startmode"   => "manual",
              "bootproto"   => "static",
              "ipaddr"      => "TheIP/24",
              "mtu"         => "1234",
              "bond_slaves" => ["eth1", "eth2", "eth3"],
              "bond_option" => "mode=active-backup miimon=100"
            }
          }
        }
      end

      before do
        allow(Yast::LanItems).to receive(:Items).with(no_args).and_return("0" => { "ifcfg" => "bond0" })
        allow(Yast::LanItems).to receive(:GetCurrentName).and_return("bond0")
        allow(Yast::LanItems).to receive(:getCurrentItem).and_return("hwinfo" => { "type" => "bond" })
        allow(Yast::LanItems).to receive(:IsCurrentConfigured).and_return(true)
        attributes.map do |k, v|
          allow(Yast::LanItems).to receive(k) { v }
        end
        allow(Yast::LanItems).to receive(:SetItem)
      end

      it "returns the correct hash" do
        expect(Yast::YaPI::NETWORK.Read).to eql(config)
        subject
      end

    end

  end

end
