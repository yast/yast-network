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
require_relative "../../test_helper"
require "y2network/wicked/config_reader"
require "y2network/wicked/dns_reader"
require "y2network/connection_configs_collection"
require "y2network/interfaces_collection"
require "y2network/s390_group_devices_collection"

describe Y2Network::Wicked::ConfigReader do
  subject(:reader) { described_class.new }

  let(:eth0) { Y2Network::Interface.new("eth0") }
  let(:wlan0) { Y2Network::Interface.new("wlan0") }
  let(:interfaces) { [eth0, wlan0] }
  let(:eth0_conn) do
    Y2Network::ConnectionConfig::Ethernet.new.tap do |conn|
      conn.interface = "eth0"
      conn.name = "eth0"
    end
  end
  let(:connections) { Y2Network::ConnectionConfigsCollection.new([eth0_conn]) }
  let(:s390_devices) { Y2Network::S390GroupDevicesCollection.new([]) }
  let(:drivers) { Y2Network::Driver.new("virtio_net", "") }
  let(:routes_file) { instance_double(CFA::RoutesFile, load: nil, routes: []) }
  let(:dns_reader) { instance_double(Y2Network::Wicked::DNSReader, config: dns) }
  let(:hostname_reader) { instance_double(Y2Network::Wicked::HostnameReader, config: hostname) }
  let(:interfaces_reader) do
    instance_double(
      Y2Network::Wicked::InterfacesReader,
      interfaces:   Y2Network::InterfacesCollection.new(interfaces),
      s390_devices: s390_devices,
      drivers:      drivers
    )
  end
  let(:connection_configs_reader) do
    instance_double(
      Y2Network::Wicked::ConnectionConfigsReader,
      connections: connections
    )
  end

  let(:dns) { double("Y2Network::Wicked::DNSReader") }
  let(:hostname) { double("Y2Network::Wicked::HostnameReader") }

  before do
    allow(Y2Network::Wicked::DNSReader).to receive(:new).and_return(dns_reader)
    allow(Y2Network::Wicked::HostnameReader).to receive(:new).and_return(hostname_reader)
    allow(Y2Network::Wicked::InterfacesReader).to receive(:new).and_return(interfaces_reader)
    allow(Y2Network::Wicked::ConnectionConfigsReader).to receive(:new)
      .and_return(connection_configs_reader)
  end

  around { |e| change_scr_root(File.join(DATA_PATH, "scr_read"), &e) }

  describe "#config" do
    it "returns a configuration including network devices" do
      config = reader.config
      expect(config.interfaces.map(&:name)).to eq(["eth0", "wlan0"])
    end

    it "returns a configuration including connection configurations" do
      config = reader.config
      expect(config.connections.to_a).to eq([eth0_conn])
    end

    context "when a connection for a not existing device is found" do
      let(:connections) do
        Y2Network::ConnectionConfigsCollection.new([eth0_conn, extra_config])
      end

      context "and it is a virtual connection" do
        let(:extra_config) do
          Y2Network::ConnectionConfig::Bridge.new.tap do |conn|
            conn.interface = "br0"
            conn.name = "br0"
            conn.ports = ["eth0"]
          end
        end

        it "creates a virtual interface" do
          config = reader.config
          bridge = config.interfaces.by_name("br0")
          expect(bridge).to be_a Y2Network::VirtualInterface
        end
      end

      context "and it is not a virtual connection" do
        let(:extra_config) do
          Y2Network::ConnectionConfig::Ethernet.new.tap do |conn|
            conn.interface = "eth1"
            conn.name = "eth1"
          end
        end

        it "creates a not present physical interface" do
          config = reader.config
          eth1 = config.interfaces.by_name("eth1")
          expect(eth1).to be_a Y2Network::PhysicalInterface
          expect(eth1).to_not be_present
        end
      end
    end

    it "links routes with detected network devices" do
      config = reader.config
      route = config.routing.routes.find(&:interface)
      iface = config.interfaces.by_name(route.interface.name)
      expect(route.interface).to be(iface)
    end

    it "returns a configuration which includes routes" do
      config = reader.config
      expect(config.routing.routes.size).to eq(4)
    end

    it "returns a configuration which includes DNS settings" do
      config = reader.config
      expect(config.dns).to eq(dns)
    end

    it "returns a configuration which includes available drivers" do
      config = reader.config
      expect(config.drivers).to eq(drivers)
    end

    it "sets the config source to :wicked" do
      config = reader.config
      expect(config.source).to eq(:wicked)
    end
  end

  describe "#forward_ipv4" do
    let(:sysctl_file) do
      instance_double(CFA::SysctlConfig,
        forward_ipv4: forward_ipv4).as_null_object
    end

    before do
      allow(CFA::SysctlConfig).to receive(:new).and_return(sysctl_file)
    end

    context "when IPv4 forwarding is allowed" do
      let(:forward_ipv4) { true }

      it "returns true" do
        expect(reader.config.routing.forward_ipv4).to be true
      end
    end

    context "when IPv4 forwarding is disabled" do
      let(:forward_ipv4) { false }

      it "returns false" do
        expect(reader.config.routing.forward_ipv4).to be false
      end
    end
  end

  describe "#forward_ipv6" do
    let(:sysctl_file) do
      instance_double(CFA::SysctlConfig,
        forward_ipv6: forward_ipv6).as_null_object
    end

    before do
      allow(CFA::SysctlConfig).to receive(:new).and_return(sysctl_file)
    end

    context "when IPv6 forwarding is allowed" do
      let(:forward_ipv6) { true }

      it "returns true" do
        expect(reader.config.routing.forward_ipv6).to be true
      end
    end

    context "when IPv6 forwarding is disabled" do
      let(:forward_ipv6) { false }

      it "returns false" do
        expect(reader.config.routing.forward_ipv6).to be false
      end
    end
  end
end
