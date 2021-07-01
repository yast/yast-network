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
require_relative "../test_helper"
require "y2network/config"
require "y2network/driver"
require "y2network/routing_table"
require "y2network/interface"
require "y2network/interfaces_collection"
require "y2network/connection_config/bridge"
require "y2network/connection_config/ethernet"
require "y2network/connection_configs_collection"
require "y2network/wicked/config_reader"
require "y2network/wicked/config_writer"
require "y2network/network_manager/config_writer"

describe Y2Network::Config do
  before do
    Y2Network::Config.reset
  end

  subject(:config) do
    described_class.new(
      interfaces: interfaces, connections: connections, routing: routing,
      drivers: drivers, source: :wicked
    )
  end

  let(:route1) { Y2Network::Route.new }
  let(:route2) { Y2Network::Route.new }

  let(:table1) { Y2Network::RoutingTable.new([route1]) }
  let(:table2) { Y2Network::RoutingTable.new([route2]) }

  let(:eth0) { Y2Network::PhysicalInterface.new("eth0") }
  let(:interfaces) { Y2Network::InterfacesCollection.new([eth0]) }

  let(:eth0_conn) do
    Y2Network::ConnectionConfig::Ethernet.new.tap do |conn|
      conn.interface = "eth0"
      conn.name = "eth0"
    end
  end
  let(:connections) { Y2Network::ConnectionConfigsCollection.new([eth0_conn]) }

  let(:virtio_net) { Y2Network::Driver.new("virtio_net", "csum=1") }
  let(:drivers) { [virtio_net] }

  let(:routing) { Y2Network::Routing.new(tables: [table1, table2]) }

  describe ".from" do
    let(:reader) do
      instance_double(
        Y2Network::Wicked::ConfigReader, read: Y2Network::IssuesResult.new(config)
      )
    end

    before do
      allow(Y2Network::ConfigReader).to receive(:for).with(:wicked)
        .and_return(reader)
    end

    it "returns the configuration from the given reader" do
      result = described_class.from(:wicked)
      expect(result.config).to eq(config)
    end
  end

  describe ".add" do
    it "adds the configuration to the register" do
      expect { Y2Network::Config.add(:yast, config) }
        .to change { Y2Network::Config.find(:yast) }
        .from(nil).to(config)
    end
  end

  describe ".find" do
    before do
      Y2Network::Config.add(:yast, config)
    end

    it "returns the registered config with the given ID" do
      expect(Y2Network::Config.find(:yast)).to eq(config)
    end

    context "when a configuration with the given ID does not exist" do
      it "returns nil" do
        expect(Y2Network::Config.find(:test)).to be_nil
      end
    end
  end

  describe "#routes" do
    it "returns routes from all tables" do
      expect(config.routing.routes).to eq([route1, route2])
    end
  end

  describe "#write" do
    let(:wicked_writer) { instance_double(Y2Network::Wicked::ConfigWriter) }
    let(:nm_writer) { instance_double(Y2Network::NetworkManager::ConfigWriter) }

    before do
      allow(Y2Network::ConfigWriter).to receive(:for).with(:wicked)
        .and_return(wicked_writer)
      allow(Y2Network::ConfigWriter).to receive(:for).with(:network_manager)
        .and_return(nm_writer)
    end

    it "writes the configuration using the writer for the given target" do
      expect(nm_writer).to receive(:write).with(config, nil, only: nil)
      config.write(target: :network_manager)
    end

    context "when the original configuration is given" do
      let(:original) { instance_double(described_class) }

      it "passes that configuration to the writer" do
        expect(wicked_writer).to receive(:write).with(config, original, only: nil)
        config.write(original: original)
      end
    end

    context "when a set of sections is given" do
      it "applies the configuration for those sections only" do
        expect(wicked_writer).to receive(:write).with(config, nil, only: [:dns])
        config.write(only: [:dns])
      end
    end

    context "when no target is given" do
      context "and a backend is set" do
        before { config.backend = :network_manager }

        it "writes the config using the writer for the backend" do
          expect(nm_writer).to receive(:write).with(config, nil, only: nil)
          config.write
        end
      end

      context "and no backend is set" do
        it "writes the config using the writer for the source" do
          expect(wicked_writer).to receive(:write).with(config, nil, only: nil)
          config.write
        end
      end
    end
  end

  describe "#copy" do
    it "returns a copy of the object" do
      copy = config.copy
      expect(copy).to_not be(config)
      expect(copy.routing.tables.size).to eq(2)
    end

    it "returns a copy whose changes won't affect to the original object" do
      copy = config.copy
      copy.routing.tables.clear
      expect(copy.routing.tables).to be_empty
      expect(config.routing.tables.size).to eq(2)
    end
  end

  describe "#==" do
    let(:bond0) { Y2Network::VirtualInterface.new("bond0") }
    let(:bond0_conn) do
      Y2Network::ConnectionConfig::Bonding.new.tap do |conn|
        conn.interface = "bond0"
        conn.name = "bond0"
        conn.slaves = ["eth0"]
      end
    end

    let(:interfaces) { Y2Network::InterfacesCollection.new([eth0, bond0]) }
    let(:connections) { Y2Network::ConnectionConfigsCollection.new([eth0_conn, bond0_conn]) }

    let(:copy) { config.copy }

    context "when both configuration contains the same information" do
      it "returns true" do
        expect(copy).to eq(config)
      end
    end

    context "when interfaces list is different" do
      it "returns false" do
        copy.interfaces = Y2Network::InterfacesCollection.new([Y2Network::Interface.new("eth1")])
        expect(copy).to_not eq(config)
      end
    end

    context "when connection list is different" do
      it "returns false" do
        modified_bond = copy.connections.by_name("bond0")
        modified_bond.options = "mode=active-backup miimon=300"

        expect(copy).to_not eq(config)
      end
    end

    context "when routing information is different" do
      it "returns false" do
        copy.routing.forward_ipv4 = !config.routing.forward_ipv4
        expect(copy).to_not eq(config)
      end
    end

    context "when hostname information is different" do
      it "returns false" do
        copy.hostname.static = "dummy"
        expect(copy).to_not eq(config)
      end
    end
  end

  describe "#rename_interface" do
    it "adjusts the interface name" do
      config.rename_interface("eth0", "eth1", :mac)
      eth1 = config.interfaces.by_name("eth1")
      expect(eth1.renaming_mechanism).to eq(:mac)
    end

    it "adjusts the connection configurations for that interface" do
      config.rename_interface("eth0", "eth1", :mac)
      eth1_conns = config.connections.by_interface("eth1")
      expect(eth1_conns).to_not be_empty
    end

    context "when the interface is renamed twice" do
      it "adjusts the interface name to the last name" do
        config.rename_interface("eth0", "eth1", :mac)
        config.rename_interface("eth1", "eth2", :bios_id)
        eth2 = config.interfaces.by_name("eth2")
        expect(eth2.renaming_mechanism).to eq(:bios_id)
      end

      it "adjusts the connection configurations for that interface using the last name" do
        config.rename_interface("eth0", "eth1", :mac)
        config.rename_interface("eth1", "eth2", :mac)
        eth2_conns = config.connections.by_interface("eth2")
        expect(eth2_conns).to_not be_empty
      end
    end

    context "when the old name is nil" do
      it "adjust renaming mechanism only" do
        config.rename_interface(nil, "eth0", :mac)
        eth1 = config.interfaces.by_name("eth0")
        expect(eth1.renaming_mechanism).to eq(:mac)
      end
    end

    context "when dhcp_hostname points to the renamed interface" do
      before do
        allow(config.hostname).to receive(:dhcp_hostname).and_return("eth0")
      end

      it "adjusts the dhcp_hostname" do
        expect(config.hostname).to receive(:dhcp_hostname=).with("eth1")
        config.rename_interface("eth0", "eth1", :mac)
      end
    end

    context "when dhcp_hostname does not point to the renamed interface" do
      before do
        allow(config.hostname).to receive(:dhcp_hostname).and_return(:any)
      end

      it "does not adjust the dhcp_hostname" do
        expect(config.hostname).to_not receive(:dhcp_hostname=)
        config.rename_interface("eth0", "eth1", :mac)
      end
    end

    context "when interface is used in bridge" do
      let(:br0) { Y2Network::VirtualInterface.new("br0") }
      let(:br0_conn) do
        Y2Network::ConnectionConfig::Bridge.new.tap do |conn|
          conn.interface = "br0"
          conn.name = "br0"
          conn.ports = ["eth0"]
        end
      end
      let(:interfaces) { Y2Network::InterfacesCollection.new([eth0, br0]) }
      let(:connections) { Y2Network::ConnectionConfigsCollection.new([eth0_conn, br0_conn]) }

      it "updates interface name in its ports" do
        expect { config.rename_interface("eth0", "eth1", :mac) }.to change { br0_conn.ports }
          .from(["eth0"]).to(["eth1"])
      end
    end

    context "when interface is used in bonding" do
      let(:bond0) { Y2Network::VirtualInterface.new("bond0") }
      let(:bond0_conn) do
        Y2Network::ConnectionConfig::Bonding.new.tap do |conn|
          conn.interface = "bond0"
          conn.name = "bond0"
          conn.slaves = ["eth0"]
        end
      end
      let(:interfaces) { Y2Network::InterfacesCollection.new([eth0, bond0]) }
      let(:connections) { Y2Network::ConnectionConfigsCollection.new([eth0_conn, bond0_conn]) }

      it "updates interface name in its slaves" do
        expect { config.rename_interface("eth0", "eth1", :mac) }.to change { bond0_conn.slaves }
          .from(["eth0"]).to(["eth1"])
      end
    end

    context "when interface is used in vlan" do
      let(:vlan0) { Y2Network::VirtualInterface.new("vlan0") }
      let(:vlan0_conn) do
        Y2Network::ConnectionConfig::Vlan.new.tap do |conn|
          conn.interface = "vlan0"
          conn.name = "vlan0"
          conn.parent_device = "eth0"
        end
      end
      let(:interfaces) { Y2Network::InterfacesCollection.new([eth0, vlan0]) }
      let(:connections) { Y2Network::ConnectionConfigsCollection.new([eth0_conn, vlan0_conn]) }

      it "updates interface name in its parent device" do
        expect { config.rename_interface("eth0", "eth1", :mac) }.to(
          change { vlan0_conn.parent_device }.from("eth0").to("eth1")
        )
      end
    end
  end

  describe "#add_or_update_connection_config" do
    let(:new_conn) do
      Y2Network::ConnectionConfig::Ethernet.new.tap do |conn|
        conn.interface = "eth2"
      end
    end

    it "adds the connection config" do
      config.add_or_update_connection_config(new_conn)
      expect(config.connections.by_name(new_conn.name)).to eq(new_conn)
    end

    context "when a connection config with the same name exists" do
      let(:other_conn) do
        Y2Network::ConnectionConfig::Ethernet.new.tap do |conn|
          conn.interface = "eth2"
        end
      end

      before do
        config.add_or_update_connection_config(new_conn)
      end

      it "updates the connection config" do
        config.add_or_update_connection_config(other_conn)
        expect(config.connections.by_name(new_conn.name)).to eq(other_conn)
      end
    end

    context "when the interface is missing" do
      let(:new_conn) do
        Y2Network::ConnectionConfig::Bridge.new.tap do |conn|
          conn.interface = "br0"
        end
      end

      it "adds the corresponding interface" do
        config.add_or_update_connection_config(new_conn)
        expect(config.interfaces.by_name("br0")).to be_a(Y2Network::VirtualInterface)
      end

      context "and the interface already exists" do
        before do
          config.interfaces << Y2Network::VirtualInterface.new("br0")
        end

        it "does not add any interface" do
          expect { config.add_or_update_connection_config(new_conn) }
            .to_not(change { config.interfaces.size })
        end
      end
    end
  end

  describe "#delete_interface" do
    let(:br0) { Y2Network::VirtualInterface.new("br0") }
    let(:br0_conn) do
      Y2Network::ConnectionConfig::Bridge.new.tap do |conn|
        conn.interface = "br0"
        conn.name = "br0"
      end
    end
    let(:interfaces) { Y2Network::InterfacesCollection.new([eth0, br0]) }
    let(:connections) { Y2Network::ConnectionConfigsCollection.new([eth0_conn, br0_conn]) }

    context "when it is not a physical interface" do
      it "removes the connection config" do
        expect { config.delete_interface(br0.name) }.to change { config.connections.to_a }
          .from([eth0_conn, br0_conn]).to([eth0_conn])
      end

      it "removes the interface" do
        expect { config.delete_interface(br0.name) }.to change { config.interfaces.to_a }
          .from([eth0, br0]).to([eth0])
      end
    end

    context "when interface is used in bridge" do
      let(:br0) { Y2Network::VirtualInterface.new("br0") }
      let(:br0_conn) do
        Y2Network::ConnectionConfig::Bridge.new.tap do |conn|
          conn.interface = "br0"
          conn.name = "br0"
          conn.ports = ["eth0"]
        end
      end
      let(:interfaces) { Y2Network::InterfacesCollection.new([eth0, br0]) }
      let(:connections) { Y2Network::ConnectionConfigsCollection.new([eth0_conn, br0_conn]) }

      it "removes interface from its ports" do
        expect { config.delete_interface(eth0.name) }.to change { br0_conn.ports }
          .from(["eth0"]).to([])
      end
    end

    context "when interface is used in bonding" do
      let(:bond0) { Y2Network::VirtualInterface.new("bond0") }
      let(:bond0_conn) do
        Y2Network::ConnectionConfig::Bonding.new.tap do |conn|
          conn.interface = "bond0"
          conn.name = "bond0"
          conn.slaves = ["eth0"]
        end
      end
      let(:interfaces) { Y2Network::InterfacesCollection.new([eth0, bond0]) }
      let(:connections) { Y2Network::ConnectionConfigsCollection.new([eth0_conn, bond0_conn]) }

      it "removes interface from its slaves" do
        expect { config.delete_interface(eth0.name) }.to change { bond0_conn.slaves }
          .from(["eth0"]).to([])
      end
    end

    context "when interface is used in vlan" do
      let(:vlan0) { Y2Network::VirtualInterface.new("vlan0") }
      let(:vlan0_conn) do
        Y2Network::ConnectionConfig::Vlan.new.tap do |conn|
          conn.interface = "vlan0"
          conn.name = "vlan0"
          conn.parent_device = "eth0"
        end
      end
      let(:interfaces) { Y2Network::InterfacesCollection.new([eth0, vlan0]) }
      let(:connections) { Y2Network::ConnectionConfigsCollection.new([eth0_conn, vlan0_conn]) }

      it "removes that vlan" do
        expect(config).to receive(:delete_interface).with("vlan0")
        # allow initial call to delete eth
        allow(config).to receive(:delete_interface).and_call_original
        config.delete_interface(eth0.name)
      end
    end

    context "when interface is used for configuring hostname via dhcp" do
      before do
        config.hostname.dhcp_hostname = eth0.name
      end

      it "sets dns dhcp hostname to :none" do
        expect { config.delete_interface(eth0.name) }.to change { config.hostname.dhcp_hostname }
          .from("eth0").to(:none)
      end
    end

    context "when it is a physical interface" do
      let(:present?) { true }

      before do
        allow(eth0).to receive(:present?).and_return(present?)
      end

      it "removes the connection config" do
        expect { config.delete_interface(eth0.name) }.to change { config.connections.to_a }
          .from([eth0_conn, br0_conn]).to([br0_conn])
      end

      it "does not remove the interface" do
        expect { config.delete_interface(eth0.name) }.to_not(
          change { config.interfaces.to_a }
        )
      end

      context "when the interface is not present" do
        let(:present?) { false }

        it "removes the interface" do
          expect { config.delete_interface(eth0.name) }.to change { config.interfaces.to_a }
            .from([eth0, br0]).to([br0])
        end
      end
    end
  end

  describe "#drivers_for_interface" do
    let(:e1000) { Y2Network::Driver.new("e1000", "") }
    let(:custom) { Y2Network::Driver.new("custom", "") }
    let(:drivers) { [virtio_net, e1000, custom] }

    before do
      allow(eth0).to receive(:drivers).and_return([Y2Network::Driver.new("virtio_net")])
    end

    it "returns the driver for a given interface" do
      drivers = config.drivers_for_interface("eth0")
      expect(drivers).to eq([virtio_net])
    end

    context "when a custom driver is set" do
      before do
        eth0.custom_driver = custom.name
      end

      it "includes the custom driver" do
        expect(config.drivers_for_interface("eth0"))
          .to include(custom)
      end
    end
  end

  describe "#add_or_update_driver" do
    let(:new_driver) { Y2Network::Driver.new("e1000", "") }

    it "adds the driver" do
      config.add_or_update_driver(new_driver)
      expect(config.drivers).to eq([virtio_net, new_driver])
    end

    context "when a driver with the same name already exists" do
      let(:new_driver) { Y2Network::Driver.new("virtio_net", "csum=0") }

      it "replaces the driver with the given one" do
        config.add_or_update_driver(new_driver)
        expect(config.drivers).to eq([new_driver])
      end
    end
  end

  describe "#configured_interface?" do
    context "when a connection for the given interface exists" do
      it "reeturns true" do
        expect(config.configured_interface?("eth0")).to eq(true)
      end
    end

    context "when no connection for the given interface exists" do
      it "reeturns false" do
        expect(config.configured_interface?("eth9")).to eq(false)
      end
    end

    context "when interface name is nil" do
      it "returns false" do
        expect(config.configured_interface?(nil)).to eq(false)
      end
    end

    context "when interface name is empty" do
      it "returns false" do
        expect(config.configured_interface?("")).to eq(false)
      end
    end
  end

  describe "#update" do
    let(:wlan0) { Y2Network::PhysicalInterface.new("wlan0") }
    let(:wlan0_conn) { Y2Network::ConnectionConfig::Wireless.new }
    let(:updated_interfaces) { Y2Network::InterfacesCollection.new([wlan0]) }
    let(:updated_connections) { Y2Network::ConnectionConfigsCollection.new([wlan0_conn]) }

    it "returns an updated configuration" do
      new_config = config.update(
        interfaces:  updated_interfaces,
        connections: updated_connections,
        source:      :network_manager
      )
      expect(config.interfaces).to eq(interfaces)
      expect(new_config.interfaces).to eq(updated_interfaces)
      expect(new_config.connections).to eq(updated_connections)
    end
  end
end
