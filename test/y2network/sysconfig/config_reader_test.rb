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
require "y2network/sysconfig/config_reader"
require "y2network/sysconfig/dns_reader"

describe Y2Network::Sysconfig::ConfigReader do
  subject(:reader) { described_class.new }

  let(:eth0) { Y2Network::Interface.new("eth0") }
  let(:wlan0) { Y2Network::Interface.new("wlan0") }
  let(:interfaces) { [eth0, wlan0] }
  let(:eth0_config) { instance_double(Y2Network::ConnectionConfig::Ethernet) }
  let(:connections) { [eth0_config] }
  let(:drivers) { Y2Network::Driver.new("virtio_net", "") }
  let(:routes_file) { instance_double(Y2Network::Sysconfig::RoutesFile, load: nil, routes: []) }
  let(:dns_reader) { instance_double(Y2Network::Sysconfig::DNSReader, config: dns) }
  let(:interfaces_reader) do
    instance_double(
      Y2Network::Sysconfig::InterfacesReader,
      interfaces:  Y2Network::InterfacesCollection.new(interfaces),
      connections: connections,
      drivers:     drivers
    )
  end

  let(:dns) { double("Y2Network::Sysconfig::DNSReader") }

  before do
    allow(Y2Network::Sysconfig::DNSReader).to receive(:new).and_return(dns_reader)
    allow(Y2Network::Sysconfig::InterfacesReader).to receive(:new).and_return(interfaces_reader)
  end

  around { |e| change_scr_root(File.join(DATA_PATH, "scr_read"), &e) }

  describe "#config" do
    it "returns a configuration including network devices" do
      config = reader.config
      expect(config.interfaces.map(&:name)).to eq(["eth0", "wlan0"])
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

    it "sets the config source to :sysconfig" do
      config = reader.config
      expect(config.source).to eq(:sysconfig)
    end
  end

  describe "#forward_ipv4?" do
    before do
      allow(Y2Network::Sysconfig::RoutesFile).to receive(:new).and_return(routes_file)
    end

    it "returns true when IPv4 forwarding is allowed" do
      expect(reader.config.routing.forward_ipv4).to be true
    end

    it "returns false when IPv4 forwarding is disabled" do
      allow(Yast::SCR).to receive(:Read).and_return("0")

      expect(reader.config.routing.forward_ipv4).to be false
    end
  end

  describe "#forward_ipv6?" do
    before do
      allow(Y2Network::Sysconfig::RoutesFile).to receive(:new).and_return(routes_file)
    end

    it "returns false when IPv6 forwarding is disabled" do
      allow(Yast::SCR).to receive(:Read).and_return("1")

      expect(reader.config.routing.forward_ipv6).to be true
    end

    it "returns false when IPv6 forwarding is disabled" do
      expect(reader.config.routing.forward_ipv6).to be false
    end
  end
end
