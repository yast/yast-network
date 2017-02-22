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

  subject { Yast::YaPI::NETWORK }

  describe ".Write" do
    let(:routing) { Yast::Routing }

    context "with routes" do
      # Mock the system to do not break anything
      before do
        allow(routing).to receive(:Read)
        allow(routing).to receive(:Routes)
        allow(routing).to receive(:Write)
      end

      let(:success) { { "error" => "", "exit" => "0" } }

      context "with no gateway in the default route" do
        let(:route) { { "default" => nil } }

        it "returns success" do
          expect(subject.Write("route" => route)).to eq success
        end

        it "empties the routes" do
          expect(routing).to receive(:Routes=).with []
          subject.Write("route" => route)
        end
      end

      context "with empty gateway in the default  route" do
        let(:route) { { "default" => { "via" => "" } } }

        it "returns success" do
          expect(subject.Write("route" => route)).to eq success
        end

        it "empties the routes" do
          expect(routing).to receive(:Routes=).with []
          subject.Write("route" => route)
        end
      end

      context "with a gateway in the default route" do

        context "if it's a valid IP4" do
          let(:route) { { "default" => { "via" => "1.2.3.4" } } }

          it "returns success" do
            expect(subject.Write("route" => route)).to eq success
          end

          it "correctly modifies the routes" do
            expect(routing).to receive(:Routes=).with(
              [
                {
                  "destination" => "default",
                  "gateway"     => "1.2.3.4",
                  "netmask"     => "-",
                  "device"      => "-"
                }
              ]
            )
            subject.Write("route" => route)
          end
        end

        context "if it's not a valid IP4" do
          let(:route) { { "default" => { "via" => "256.256.256.256" } } }

          it "returns failure" do
            res = subject.Write("route" => route)
            expect(res["exit"]).to eq "-1"
            expect(res["error"]).not_to be_empty
          end

          it "doesnt't modify the routes" do
            expect(routing).not_to receive(:Routes=)
            subject.Write("route" => route)
          end
        end
      end
    end

    context "with interfaces" do
      let(:network_interfaces) { Yast::NetworkInterfaces }

      before do
        interface.keys.map do |k|
          stub_clean_cache(k)
        end
      end

      context("setting bootproto and startmode") do
        let(:interface) { { "eth0" => { "bootproto" => "dhcp6", "startmode" => "onboot" } } }

        it "sets both parameters correctly" do
          expect(network_interfaces).to receive(:Current=).with(
            "BOOTPROTO" => "dhcp6",
            "STARTMODE" => "onboot"
          )
          stub_write_interfaces
          subject.Write("interface" => interface)
        end
      end

      context("setting IP address and netmask") do
        let(:interface) { { "eth0" => { "ipaddr" => "1.2.3.4/#{netmask}" } } }

        context("with valid netmask in dot notation") do
          let(:netmask) { "255.255.255.0" }

          it "converts netmask to CIDR" do
            expect(network_interfaces).to receive(:Current=).with(
              "BOOTPROTO" => "static",
              "STARTMODE" => "auto",
              "IPADDR"    => "1.2.3.4/24"
            )
            stub_write_interfaces
            subject.Write("interface" => interface)
          end
        end

        context("with valid netmask in CIDR notation") do
          let(:netmask) { "16" }

          it "keeps netmask untouched" do
            expect(network_interfaces).to receive(:Current=).with(
              "BOOTPROTO" => "static",
              "STARTMODE" => "auto",
              "IPADDR"    => "1.2.3.4/#{netmask}"
            )
            stub_write_interfaces
            subject.Write("interface" => interface)
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
          expect(network_interfaces).to receive(:Current=).with(
            "BOOTPROTO"   => "static",
            "STARTMODE"   => "auto",
            "IPADDR"      => "1.2.3.8/24",
            "ETHERDEVICE" => "eth5",
            "VLAN_ID"     => "42"
          )
          stub_write_interfaces
          subject.Write("interface" => interface)
        end
      end

      context("setting a bond interface with required parameters") do
        let(:interface) { { "bond0" => { "bond" => "yes", "bond_slaves" => "eth1" } } }

        it "sets default values" do
          expect(network_interfaces).to receive(:Current=).with(
            "BOOTPROTO"           => "static",
            "STARTMODE"           => "auto",
            "BONDING_MASTER"      => "yes",
            "BONDING_MODULE_OPTS" => nil,
            "BONDING_SLAVE0"      => "eth1"
          )
          stub_write_interfaces
          subject.Write("interface" => interface)
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
          expect(network_interfaces).to receive(:Current=).with(
            "BOOTPROTO"           => "static",
            "STARTMODE"           => "auto",
            "BONDING_MASTER"      => "yes",
            "BONDING_MODULE_OPTS" => "mode=active-backup miimon=100",
            "BONDING_SLAVE0"      => "eth1",
            "BONDING_SLAVE1"      => "eth4",
            "BONDING_SLAVE2"      => "eth5"
          )
          stub_write_interfaces
          subject.Write("interface" => interface)
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
        ipaddr:    "1.2.3.4",
        prefix:    "24",
        mtu:       "1234"
      }.merge(context_attributes)
    end
    let(:lan_items) { Yast::LanItems }

    before do
      stub_network_reads
      allow(Yast::Routing).to receive(:GetGateway).and_return "1.2.3.4"
      allow(Yast::Hostname).to receive(:CurrentHostname).and_return "Hostname"
      allow(Yast::Hostname).to receive(:CurrentDomain).and_return "TheDomain"
      allow(Yast::DNS).to receive(:dhcp_hostname).and_return "Hostname"
      allow(Yast::DNS).to receive(:nameservers).and_return []
      allow(Yast::DNS).to receive(:searchlist).and_return ["suse.com"]
    end

    let(:config) do
      {
        "routes"   => {
          "default" => {
            "via" => "1.2.3.4"
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

    context "with no interfaces" do
      let(:interfaces) do
        {
          "interfaces" => {}
        }
      end

      it "returns the correct hash" do
        allow(lan_items).to receive(:Items).with(no_args).and_return({})
        expect(subject.Read).to eql(config)
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
              "ipaddr"           => "1.2.3.4/24",
              "mtu"              => "1234",
              "vlan_id"          => "42",
              "vlan_etherdevice" => "eth5",
              "vendor"           => "eth5.23"
            }
          }
        }
      end

      before do
        allow(lan_items).to receive(:Items).with(no_args).and_return("0" => { "ifcfg" => "eth5.23" })
        allow(lan_items).to receive(:GetCurrentName).and_return("eth5.23")
        allow(lan_items).to receive(:getCurrentItem).and_return(
          "hwinfo" => { "dev_name" => "eth5.23", "type" => "eth", "name" => "eth5.23" }
        )
        allow(lan_items).to receive(:IsCurrentConfigured).and_return(true)
        attributes.map do |k, v|
          allow(lan_items).to receive(k) { v }
        end
        allow(lan_items).to receive(:SetItem)
      end

      it "returns the correct hash" do
        expect(subject.Read).to eql(config)
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
              "ipaddr"      => "1.2.3.4/24",
              "mtu"         => "1234",
              "bond_slaves" => ["eth1", "eth2", "eth3"],
              "bond_option" => "mode=active-backup miimon=100"
            }
          }
        }
      end

      before do
        allow(lan_items).to receive(:Items).with(no_args).and_return("0" => { "ifcfg" => "bond0" })
        allow(lan_items).to receive(:GetCurrentName).and_return("bond0")
        allow(lan_items).to receive(:getCurrentItem).and_return("hwinfo" => { "type" => "bond" })
        allow(lan_items).to receive(:IsCurrentConfigured).and_return(true)
        attributes.map do |k, v|
          allow(lan_items).to receive(k) { v }
        end
        allow(lan_items).to receive(:SetItem)
      end

      it "returns the correct hash" do
        expect(subject.Read).to eql(config)
      end

    end

  end

end
