#!/usr/bin/env rspec

# Copyright (c) [2019] SUSE LLC
#
# All Rights Reserved.
#
# This program is free software; you can redistribute it and/or modify it
# under the terms of version 2 of the GNU General Public License as published
# by the Free Software Foundation.
#
# This program is distributed in the hope that it will be useful, but WITHOUT
# ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or
# FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License for
# more details.
#
# You should have received a copy of the GNU General Public License along
# with this program; if not, contact SUSE LLC.
#
# To contact SUSE LLC about this file by physical or electronic mail, you may
# find current contact information at www.suse.com.

require_relative "test_helper"

require "yast"
require "network/network_autoconfiguration"
require "y2network/virtual_interface"
require "y2network/routing"
require "y2network/routing_table"
require "y2network/route"

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
  let(:yast_config) do
    Y2Network::Config.new(interfaces: interfaces, connections: connections, source: :source)
  end
  let(:eth0) { Y2Network::Interface.new("eth0") }
  let(:interfaces) { Y2Network::InterfacesCollection.new([eth0]) }
  let(:connections) { Y2Network::ConnectionConfigsCollection.new([eth0_conn]) }
  let(:eth0_conn) { Y2Network::ConnectionConfig::Ethernet.new.tap { |c| c.name = eth0.name } }
  let(:source) { :wicked }
  let(:system_config) { yast_config.copy }
  let(:instance) { Yast::NetworkAutoconfiguration.instance }

  before do
    Y2Network::Config.add(:yast, yast_config)
    Y2Network::Config.add(:system, system_config)
    allow(Yast::Lan).to receive(:Read)
    allow(Yast::Lan).to receive(:read_config)
    allow(Yast::Lan).to receive(:write_config)
  end

  describe "#any_iface_active?" do
    let(:active) { false }
    let(:firmware_interfaces) { [] }
    let(:eth1) { Y2Network::Interface.new("eth1") }
    let(:interfaces) { Y2Network::InterfacesCollection.new([eth1, eth0]) }

    before do
      allow(instance).to receive(:active_config?).with("eth1").and_return(false)
      allow(instance).to receive(:active_config?).with("eth0").and_return(active)
      allow(instance).to receive(:firmware_interfaces).and_return(firmware_interfaces)
    end

    it "returns false if there is no interface UP" do
      expect(instance.any_iface_active?).to be false
    end

    context "when at least one interface is UP" do
      let(:active) { true }

      context "and the interface is configured through firmware" do
        let(:firmware_interfaces) { [eth0.name] }

        it "returns true" do
          expect(instance.any_iface_active?).to be true
        end
      end

      context "and the interface has a configuration file" do
        it "returns true" do
          expect(instance.any_iface_active?).to be true
        end
      end

      context "but the interface is not configured" do
        let(:connections) { Y2Network::ConnectionConfigsCollection.new([]) }

        it "returns false" do
          expect(instance.any_iface_active?).to be false
        end
      end
    end
  end

  describe "#dhcp_candidate?" do
    let(:firmware_interfaces) { [] }
    let(:connected) { true }
    let(:connections) { Y2Network::ConnectionConfigsCollection.new([]) }

    before do
      allow(instance).to receive(:firmware_interfaces).and_return(firmware_interfaces)
      allow(instance).to receive(:phy_connected?).with(eth0.name).and_return(connected)
    end

    context "when the given interface has a config file" do
      let(:connections) { Y2Network::ConnectionConfigsCollection.new([eth0_conn]) }

      it "returns false" do
        expect(instance.dhcp_candidate?(eth0)).to eql(false)
      end
    end

    context "when the given interface is configured by firmware" do
      let(:firmware_interfaces) { [eth0.name] }

      it "returns false" do
        expect(instance.dhcp_candidate?(eth0)).to eql(false)
      end
    end

    context "when the interface is not configured" do
      context "and it is not connected" do
        let(:connected) { false }

        it "returns false" do
          expect(instance.dhcp_candidate?(eth0)).to eql(false)
        end
      end

      context "and it is connected" do
        it "returns true" do
          expect(instance.dhcp_candidate?(eth0)).to eql(true)
        end
      end
    end
  end

  describe "#configure_dhcp" do
    before do
      allow(instance).to receive(:dhcp_candidate?).and_return(false)
      allow(instance).to receive(:setup_dhcp)
      allow(instance).to receive(:activate_changes)
      allow(instance).to receive(:set_default_route_flag)
      allow(instance).to receive(:set_default_route_flag_if_wan_dev?)
    end

    it "reads the network configuration in case it was not cached" do
      expect(Yast::Lan).to receive(:Read).with(:cache)
      expect(instance.configure_dhcp)
    end

    it "obtains a list of interfaces which are candidates to be configured by dhcp" do
      expect(instance).to receive(:dhcp_candidate?).with(eth0).and_return(true)
      expect(instance.configure_dhcp)
    end

    context "when there is no candidate to setup" do
      it "returns whitout doing changes to the config" do
        expect(instance).to_not receive(:activate_changes)
        expect(instance.configure_dhcp)
      end
    end

    context "when there is some candidate to setup" do
      before do
        allow(instance).to receive(:dhcp_candidate?).with(eth0).and_return(true)
      end

      it "creates a DHCP configuration for the candidate interfaces" do
        expect(instance).to receive(:setup_dhcp).with(eth0)
        instance.configure_dhcp
      end

      it "applies the new configuration changes" do
        expect(instance).to receive(:activate_changes).with([eth0.name])
        instance.configure_dhcp
      end

      context "if some of the new configured interfaces do not get a DHCP lease" do
        it "deletes the configuration of the inactive devices" do
          expect(instance).to receive(:activate_changes).with([eth0.name])
          expect(instance).to receive(:active_config?).with(eth0.name).and_return(false)
          expect(instance).to receive(:delete_config).with(eth0)
          instance.configure_dhcp
        end
      end

      it "configures just one NIC to have a default route" do
        expect(instance).to receive(:active_config?).with(eth0.name).and_return(true)
        expect(instance).to receive(:set_default_route_flag).with(eth0, "yes")
        instance.configure_dhcp
      end
    end
  end

  describe "#virtual_proposal_required?" do
    let(:is_s390) { false }
    let(:installed) { [] }

    before do
      allow(Yast::Arch).to receive(:s390).and_return(is_s390)
      allow(Yast::Package).to receive(:Installed).and_return(false)
      installed.map do |package|
        allow(Yast::Package).to receive(:Installed).with(package).and_return(true)
      end
    end

    context "in s390 arch" do
      let(:is_s390) { true }

      it "returns false" do
        expect(instance.virtual_proposal_required?).to eql(false)
      end
    end

    context "when KVM, Xen or QEMU packages are not installed" do
      it "returns false" do
        expect(instance.virtual_proposal_required?).to eql(false)
      end
    end

    context "when XEN is installed" do
      let(:installed) { ["xen"] }

      context "and we are in a guest machine" do
        it "returns false" do
          allow(Yast::Arch).to receive(:is_xen0).and_return(false)
          expect(instance.virtual_proposal_required?).to eql(false)
        end
      end

      context "and we are in the host machine" do
        it "returns true" do
          allow(Yast::Arch).to receive(:is_xen0).and_return(true)
          expect(instance.virtual_proposal_required?).to eql(true)
        end
      end

      context "when KVM is installed" do
        let(:installed) { ["kvm"] }

        it "returns true" do
          expect(instance.virtual_proposal_required?).to eql(true)
        end
      end

      context "when QEMU is installed" do
        let(:installed) { ["qemu"] }

        it "returns true" do
          expect(instance.virtual_proposal_required?).to eql(true)
        end
      end
    end
  end

  describe "#configure_hosts" do
    before do
      allow(Yast::Host).to receive(:Write)
    end

    it "ensures the /etc/hosts configuration is read" do
      expect(Yast::Host).to receive(:Read)
      instance.configure_hosts
    end

    it "adds and entry for the static IP addresses without one pointing to the hostname" do
      expect(Yast::Host).to receive(:ResolveHostnameToStaticIPs)
      instance.configure_hosts
    end

    it "writes the /etc/hosts changes" do
      expect(Yast::Host).to receive(:Write)
      instance.configure_hosts
    end
  end

  describe "#configure_virtuals" do
    let(:routing) { Y2Network::Routing.new(tables: [table1]) }
    let(:table1) { Y2Network::RoutingTable.new(routes) }
    let(:routes) { [route] }
    let(:route) do
      Y2Network::Route.new(to:        :default,
        gateway:   IPAddr.new("192.168.122.1"),
        interface: eth5)
    end
    let(:eth5) { Y2Network::Interface.new("eth5") }
    let(:br0) { Y2Network::VirtualInterface.new("br0") }
    let(:interfaces) { Y2Network::InterfacesCollection.new([eth5, br0]) }
    let(:yast_config) do
      Y2Network::Config.new(interfaces: interfaces, routing: routing, source: :testing)
    end
    let(:proposal) { false }
    let(:eth0_profile) do
      {
        "bootproto" => "static",
        "ipaddr"    => "192.168.122.213",
        "netmask"   => "255.255.255.0",
        "startmode" => "auto",
        "device"    => "eth0"
      }
    end
    let(:routes_profile) do
      [
        {
          "destination" => "default",
          "gateway"     => "192.168.122.1",
          "netmask"     => "-",
          "device"      => "eth0"
        }
      ]
    end

    before do
      allow(Y2Network::Config).to receive(:find).with(:yast).and_return(yast_config)
      allow(Y2Network::Config).to receive(:find).with(:system).and_return(system_config)
      allow(instance).to receive(:virtual_proposal_required?).and_return(proposal)
      allow(Yast::Lan).to receive(:write_config)
      allow_any_instance_of(Y2Network::VirtualizationConfig)
        .to receive(:connected_and_bridgeable?).and_return(true)
      allow(Yast::Package).to receive(:Installed).and_return(true)
      Yast::Lan.Import(
        "routing" => { "routes" => routes_profile }
      )
    end

    context "when the proposal is not required" do
      it "does nothing" do
        expect(Yast::Lan).to_not receive(:ProposeVirtualized)
        instance.configure_virtuals
      end
    end

    context "when the proposal is required" do
      let(:interfaces) { Y2Network::InterfacesCollection.new([eth5]) }
      let(:proposal) { true }

      it "creates the virtulization proposal config" do
        expect(Yast::Lan).to receive(:ProposeVirtualized).and_call_original
        expect { instance.configure_virtuals }.to(
          change { yast_config.connections.size }.from(0).to(2)
        )
      end

      it "writes the configuration of the interfaces" do
        expect(Yast::Lan).to receive(:write_config)
        instance.configure_virtuals
      end

      context "and the routing config was modified" do
        it "moves the routes from the bridge port to the bridge" do
          expect { instance.configure_virtuals }.to change { route.interface }.from(eth5).to(br0)
        end

        it "writes the routing config" do
          expect(Yast::Lan).to receive(:write_config)
          instance.configure_virtuals
        end
      end
    end
  end
end
