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

describe Y2Network::Wicked::ConfigReader do
  subject(:reader) { described_class.new }

  let(:eth0) { Y2Network::Interface.new("eth0") }
  let(:wlan0) { Y2Network::Interface.new("wlan0") }
  let(:interfaces) { [eth0, wlan0] }
  let(:eth0_config) { instance_double(Y2Network::ConnectionConfig::Ethernet) }
  let(:connections) { [eth0_config] }
  let(:s390_devices) { [] }
  let(:drivers) { Y2Network::Driver.new("virtio_net", "") }
  let(:routes_file) { instance_double(CFA::RoutesFile, load: nil, routes: []) }
  let(:dns_reader) { instance_double(Y2Network::Wicked::DNSReader, config: dns) }
  let(:hostname_reader) { instance_double(Y2Network::Wicked::HostnameReader, config: hostname) }
  let(:interfaces_reader) do
    instance_double(
      Y2Network::Wicked::InterfacesReader,
      interfaces:   Y2Network::InterfacesCollection.new(interfaces),
      connections:  connections,
      s390_devices: s390_devices,
      drivers:      drivers
    )
  end

  let(:dns) { double("Y2Network::Wicked::DNSReader") }
  let(:hostname) { double("Y2Network::Wicked::HostnameReader") }

  before do
    allow(Y2Network::Wicked::DNSReader).to receive(:new).and_return(dns_reader)
    allow(Y2Network::Wicked::HostnameReader).to receive(:new).and_return(hostname_reader)
    allow(Y2Network::Wicked::InterfacesReader).to receive(:new).and_return(interfaces_reader)
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
