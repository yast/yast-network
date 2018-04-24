#!/usr/bin/env rspec

require_relative "test_helper"

require "yast"

Yast.import "Lan"

describe "LanClass#Packages" do
  before(:each) do
    allow(Yast::NetworkService)
      .to receive(:is_network_manager)
      .and_return(nm_enabled)
  end

  context "When NetworkManager is not going to be installed" do
    let(:nm_enabled) { false }

    before(:each) do
      allow(Yast::PackageSystem)
        .to receive(:Installed)
        .with("wpa_supplicant")
        .at_least(:once)
        .and_return(false)
    end

    it "does not list wpa_supplicant package when WIRELESS_AUTH_MODE is not psk or eap" do
      expect(Yast::NetworkInterfaces)
        .to receive(:Locate)
        .with("WIRELESS_AUTH_MODE", /(psk|eap)/)
        .at_least(:once)
        .and_return([])

      expect(Yast::Lan.Packages).not_to include "wpa_supplicant"
    end

    it "lists wpa_supplicant package when WIRELESS_AUTH_MODE is psk or eap" do
      # when checking options, LanClass#Packages currently cares only if
      # WIRELESS_AUTH_MODE={psk, eap} is present
      expect(Yast::NetworkInterfaces)
        .to receive(:Locate)
        .with("WIRELESS_AUTH_MODE", /(psk|eap)/)
        .at_least(:once)
        .and_return(["place_holder"])

      expect(Yast::Lan.Packages).to include "wpa_supplicant"
    end
  end

  context "When NetworkManager is selected for the target" do
    let(:nm_enabled) { true }

    it "lists NetworkManager package" do
      expect(Yast::NetworkService)
        .to receive(:is_network_manager)
        .and_return(true)
      expect(Yast::PackageSystem)
        .to receive(:Installed)
        .with("NetworkManager")
        .at_least(:once)
        .and_return(false)
      expect(Yast::Lan.Packages).to include "NetworkManager"
    end
  end
end

describe "LanClass#activate_network_service" do
  Yast.import "Stage"
  Yast.import "NetworkService"

  [0, 1].each do |linuxrc_usessh|
    ssh_flag = linuxrc_usessh != 0

    context format("when linuxrc %s usessh flag", ssh_flag ? "sets" : "doesn't set") do
      before(:each) do
        allow(Yast::Linuxrc)
          .to receive(:usessh)
          .and_return(ssh_flag)
      end

      context "when asked in normal mode" do
        before(:each) do
          allow(Yast::Stage)
            .to receive(:normal)
            .and_return(true)
        end

        it "tries to reload network service" do
          expect(Yast::NetworkService)
            .to receive(:ReloadOrRestart)

          Yast::Lan.send(:activate_network_service)
        end
      end

      context "when asked during installation" do
        before(:each) do
          allow(Yast::Stage)
            .to receive(:normal)
            .and_return(false)
        end

        it "updates network service according usessh flag" do
          if ssh_flag
            expect(Yast::NetworkService)
              .not_to receive(:ReloadOrRestart)
          else
            expect(Yast::NetworkService)
              .to receive(:ReloadOrRestart)
          end

          Yast::Lan.send(:activate_network_service)
        end
      end
    end
  end
end

describe "LanClass#Import" do
  let(:ay_profile) do
    {
      "devices" => {
        "eth" => {
          "eth0" => {
            "BOOTPROTO" => "static",
            "BROADCAST" => "192.168.127.255",
            "IPADDR"    => "192.168.73.138",
            "NETMASK"   => "255.255.192.0",
            "STARTMODE" => "manual"
          }
        }
      }
    }
  end

  it "flushes internal state of LanItems correctly when asked for reset" do
    expect(Yast::Lan.Import(ay_profile)).to be true
    expect(Yast::LanItems.GetModified).to be true
    expect(Yast::LanItems.Items).not_to be_empty

    expect(Yast::Lan.Import({})).to be true
    expect(Yast::LanItems.GetModified).to be false
    expect(Yast::LanItems.Items).to be_empty
  end

  it "reads the current /etc/hosts entries" do
    expect(Yast::Host).to receive(:Read)

    Yast::Lan.Import(ay_profile)
  end
end

describe "LanClass#Modified" do
  def reset_modification_statuses
    allow(Yast::LanItems).to receive(:GetModified).and_return false
    allow(Yast::DNS).to receive(:modified).and_return false
    allow(Yast::Routing).to receive(:Modified).and_return false
    allow(Yast::NetworkConfig).to receive(:Modified).and_return false
    allow(Yast::NetworkService).to receive(:Modified).and_return false
  end

  def expect_modification_succeedes(modname, method)
    reset_modification_statuses

    allow(modname)
      .to receive(method)
      .and_return true

    expect(modname.send(method)).to be true
    expect(Yast::Lan.Modified).to be true
  end

  it "returns true when LanItems module was modified" do
    expect_modification_succeedes(Yast::LanItems, :GetModified)
  end

  it "returns true when DNS module was modified" do
    expect_modification_succeedes(Yast::DNS, :modified)
  end

  it "returns true when Routing module was modified" do
    expect_modification_succeedes(Yast::Routing, :Modified)
  end

  it "returns true when NetworkConfig module was modified" do
    expect_modification_succeedes(Yast::NetworkConfig, :Modified)
  end

  it "returns true when NetworkService module was modified" do
    expect_modification_succeedes(Yast::NetworkService, :Modified)
  end

  it "returns false when no module was modified" do
    reset_modification_statuses
    expect(Yast::Lan.Modified).to be false
  end
end

describe "LanClass#readIPv6" do
  it "reads IPv6 setup from /etc/sysctl.conf" do
    allow(Yast::FileUtils).to receive(:Exists).and_return(true)
    string_stub_scr_read("/etc/sysctl.conf")

    expect(Yast::Lan.readIPv6).to be false
  end

  it "returns true when /etc/sysctl.conf is missing" do
    allow(Yast::FileUtils).to receive(:Exists).and_return(false)

    expect(Yast::Lan.readIPv6).to be true
  end
end

describe "LanClass#IfcfgsToSkipVirtualizedProposal" do
  let(:items) do
    {
      "0" => { "ifcfg" => "bond0" },
      "1" => { "ifcfg" => "br0" },
      "2" => { "ifcfg" => "eth0" },
      "3" => { "ifcfg" => "eth1" },
      "4" => { "ifcfg" => "wlan0" },
      "5" => { "ifcfg" => "wlan1" }
    }
  end

  let(:current_interface) do
    {
      "ONBOOT"       => "yes",
      "BOOTPROTO"    => "dhcp",
      "DEVICE"       => "br1",
      "BRIDGE"       => "yes",
      "BRIDGE_PORTS" => "eth1",
      "BRIDGE_STP"   => "off",
      "IPADDR"       => "10.0.0.1",
      "NETMASK"      => "255.255.255.0"
    }
  end

  context "when various interfaces are present in the system" do
    before do
      allow(Yast::NetworkInterfaces).to receive(:GetType).with("br0").and_return("br")
      allow(Yast::NetworkInterfaces).to receive(:GetType).with("bond0").and_return("bond")
      allow(Yast::NetworkInterfaces).to receive(:GetType).with("eth0").and_return("eth")
      allow(Yast::NetworkInterfaces).to receive(:GetType).with("eth1").and_return("eth")
      allow(Yast::NetworkInterfaces).to receive(:GetType).with("wlan0").and_return("usb")
      allow(Yast::NetworkInterfaces).to receive(:GetType).with("wlan1").and_return("wlan")
      allow(Yast::NetworkInterfaces).to receive(:Current).and_return(current_interface)
      allow(Yast::NetworkInterfaces).to receive(:GetValue).and_return(nil)
      allow(Yast::LanItems).to receive(:Items).and_return(items)
    end

    context "and one of them is a bridge" do
      it "returns an array containining the bridge interface" do
        (expect Yast::Lan.IfcfgsToSkipVirtualizedProposal).to include("br0")
      end

      it "returns an array containing the bridged interfaces" do
        allow(Yast::NetworkInterfaces).to receive(:GetValue)
          .with("br0", "BRIDGE_PORTS").and_return("eth1")

        expect(Yast::Lan.IfcfgsToSkipVirtualizedProposal).to include("eth1")
        expect(Yast::Lan.IfcfgsToSkipVirtualizedProposal).to_not include("eth0")
      end
    end

    context "and one of them is a bond" do
      let(:current_interface) do
        {
          "BOOTPROTO"      => "static",
          "BONDING_MASTER" => "yes",
          "DEVICE"         => "bond0",
          "BONDING_SLAVE"  => "eth0"
        }
      end

      it "returns an array containing the bonded interfaces" do
        expect(Yast::Lan.IfcfgsToSkipVirtualizedProposal).not_to include("bond0")
      end
    end

    context "and one  of them is an usb or a wlan interface" do
      it "returns an array containing the interface" do
        expect(Yast::Lan.IfcfgsToSkipVirtualizedProposal).to include("wlan0", "wlan1")
      end
    end

    context "and the interface startmode is 'nfsroot'" do
      it "returns an array containing the interface" do
        allow(Yast::NetworkInterfaces).to receive(:GetValue)
          .with("eth0", "STARTMODE").and_return("nfsroot")

        expect(Yast::Lan.IfcfgsToSkipVirtualizedProposal).to include("eth0")
      end
    end

    context "and all the interfaces are bridgeable" do
      let(:current_item) do
        {
          "BOOTPROTO" => "dhcp",
          "STARTMODE" => "auto"
        }
      end
      it "returns an empty array" do
        allow(Yast::NetworkInterfaces).to receive(:GetType).and_return("eth")
        expect(Yast::Lan.IfcfgsToSkipVirtualizedProposal).to eql([])
      end
    end
  end

  context "there is no interfaces in the system" do
    it "returns an empty array" do
      allow(Yast::LanItems).to receive(:Items).and_return({})
      expect(Yast::Lan.IfcfgsToSkipVirtualizedProposal).to eql([])
    end
  end
end

describe "LanClass#ProposeVirtualized" do

  before do
    allow(Yast::NetworkInterfaces).to receive(:GetFreeDevice).with("br").and_return("1")
    allow(Yast::LanItems).to receive(:IsCurrentConfigured).and_return(true)
    allow(Yast::Lan).to receive(:ProposeItem)
    allow(Yast::Lan).to receive(:configure_as_bridge!)
    allow(Yast::Lan).to receive(:configure_as_bridge_port)
    allow(Yast::Lan).to receive(:refresh_lan_items)

    allow(Yast::LanItems).to receive(:Items)
      .and_return(
        0 => { "ifcfg" => "eth0" }, 1 => { "ifcfg" => "wlan0", 2 => { "ifcfg" => "br0" } }
      )
  end

  context "when an interface is not bridgeable" do
    it "does not propose the interface" do
      allow(Yast::LanItems).to receive(:IsBridgeable).with(anything, anything).and_return(false)
      allow(Yast::LanItems).to receive(:IsCurrentConfigured).and_return(false)
      expect(Yast::Lan).not_to receive(:ProposeItem)

      Yast::Lan.ProposeVirtualized
    end
  end

  context "when an interface is bridgeable" do
    before do
      allow(Yast::Lan).to receive(:connected_and_bridgeable?)
        .with(anything, 0, anything).and_return(true)
      allow(Yast::Lan).to receive(:connected_and_bridgeable?)
        .with(anything, 1, anything).and_return(false)
      allow(Yast::Lan).to receive(:connected_and_bridgeable?)
        .with(anything, 2, anything).and_return(false)
    end

    it "does not configure the interface if it is not connected" do
      allow(Yast::Lan).to receive(:connected_and_bridgeable?).with(anything).and_return(false)
      expect(Yast::Lan).not_to receive(:ProposeItem)

      Yast::Lan.ProposeVirtualized
    end

    it "configures the interface with defaults before anything if not configured" do
      allow(Yast::LanItems).to receive(:IsCurrentConfigured).and_return(false)
      expect(Yast::LanItems).to receive(:ProposeItem)

      Yast::Lan.ProposeVirtualized
    end

    it "configures a new bridge with the given interface as a bridge port" do
      expect(Yast::Lan).to receive(:configure_as_bridge!).with("eth0", "br1")

      Yast::Lan.ProposeVirtualized
    end

    it "configures the given interface as a bridge port" do
      expect(Yast::Lan).to receive(:configure_as_bridge!).with("eth0", "br1").and_return(true)
      expect(Yast::Lan).to receive(:configure_as_bridge_port).with("eth0")

      Yast::Lan.ProposeVirtualized
    end

    it "refreshes lan items with the new interfaces" do
      expect(Yast::Lan).to receive(:configure_as_bridge!).with("eth0", "br1").and_return(true)
      expect(Yast::Lan).to receive(:configure_as_bridge_port).with("eth0")
      expect(Yast::Lan).to receive(:refresh_lan_items)

      Yast::Lan.ProposeVirtualized
    end
  end
end

describe "LanClass#FromAY" do
  it "makes a minimal structure from an empty input" do
    expected = {
      "config"     => { "dhcp"=>{} },
      "devices"    => {},
      "hwcfg"      => {},
      "interfaces" => []
    }
    expect(Yast::Lan.FromAY({})).to eq(expected)
  end

  it "converts 'interfaces' into nested 'devices'" do
    input = {
      "interfaces" => [
        {
          "bootproto"   => "static",
          "device"      => "eth1",
          "ipaddr"      => "10.1.1.1",
          "name"        => "Ethernet Card 0",
          "prefixlen"   => "24",
          "startmode"   => "auto",
          "usercontrol" => "no"
        }
      ]
    }
    expected = {
      "eth" => {
        "eth1" => {
          "BOOTPROTO"   => "static",
          "IPADDR"      => "10.1.1.1",
          "NAME"        => "Ethernet Card 0",
          "PREFIXLEN"   => "24",
          "STARTMODE"   => "auto",
          "USERCONTROL" => "no"
        }
      }
    }

    expect(Yast::Lan.FromAY(input)["devices"]).to eq(expected)
  end

  it "converts DHCP options" do
    input = {
      "dhcp_options" => {
        "dhclient_hostname_option" => "AUTO"
      },
      "dns"          => {
        "dhcp_hostname"      => false,
        "domain"             => "example.com",
        "hostname"           => "eg",
        "nameservers"        => ["10.10.0.100"],
        "resolv_conf_policy" => "auto",
        "searchlist"         => ["example.com"],
        "write_hostname"     => false
      }
    }
    expected_config = {
      "dhcp" => {
        "DHCLIENT_HOSTNAME_OPTION" => "AUTO",
        "DHCLIENT_SET_HOSTNAME"    => false
      }
    }

    actual = Yast::Lan.FromAY(input)
    expect(actual["config"]).to eq(expected_config)
  end
end
