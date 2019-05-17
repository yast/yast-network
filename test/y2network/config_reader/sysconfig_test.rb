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
require "y2network/config_reader/sysconfig"
require "y2network/config_reader/sysconfig_dns"

describe Y2Network::ConfigReader::Sysconfig do
  subject(:reader) { described_class.new }

  let(:network_interfaces) do
    instance_double(
      Yast::NetworkInterfacesClass,
      Read: nil,
      List: ["lo", "eth0", "wlan0"]
    )
  end

  let(:routes_file) { instance_double(Y2Network::SysconfigRoutesFile, load: nil, routes: []) }
  let(:dns_reader) { instance_double(Y2Network::ConfigReader::SysconfigDNS, config: dns) }
  let(:dns) { double("Y2Network::ConfigReader::DNS") }

  before do
    allow(Y2Network::ConfigReader::SysconfigDNS).to receive(:new).and_return(dns_reader)
  end

  around { |e| change_scr_root(File.join(DATA_PATH, "scr_read"), &e) }

  describe "#config" do
    before do
      stub_const("Yast::NetworkInterfaces", network_interfaces)
    end

    it "returns a configuration including network devices" do
      config = reader.config
      expect(config.interfaces.map(&:name)).to eq(["lo", "eth0", "wlan0"])
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

    it "sets the config source to :sysconfig" do
      config = reader.config
      expect(config.source).to eq(:sysconfig)
    end
  end

  describe "#forward_ipv4?" do
    before do
      allow(Y2Network::SysconfigRoutesFile).to receive(:new).and_return(routes_file)
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
      allow(Y2Network::SysconfigRoutesFile).to receive(:new).and_return(routes_file)
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
