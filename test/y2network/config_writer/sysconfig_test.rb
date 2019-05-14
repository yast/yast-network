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
require "y2network/config_writer/sysconfig"
require "y2network/config"
require "y2network/interface"
require "y2network/routing"
require "y2network/route"
require "y2network/routing_table"
require "y2network/sysconfig_paths"

describe Y2Network::ConfigWriter::Sysconfig do
  subject(:writer) { described_class.new }

  describe "#write" do
    let(:config) do
      Y2Network::Config.new(
        interfaces: [eth0],
        routing:    routing,
        source:     :sysconfig
      )
    end

    let(:eth0) { Y2Network::Interface.new("eth0") }
    let(:route) do
      Y2Network::Route.new(
        to:        IPAddr.new("10.0.0.2/8"),
        interface: eth0,
        gateway:   IPAddr.new("192.168.122.1")
      )
    end
    let(:default_route) do
      Y2Network::Route.new(
        gateway:   IPAddr.new("192.168.122.2")
      )
    end
    let(:forward_ipv4) { false }
    let(:forward_ipv6) { false }
    let(:routing) do
      Y2Network::Routing.new(
        tables:       [Y2Network::RoutingTable.new(routes)],
        forward_ipv4: forward_ipv4,
        forward_ipv6: forward_ipv6
      )
    end

    let(:ifroute_eth0) do
      instance_double(Y2Network::SysconfigRoutesFile, save: nil, :routes= => nil)
    end

    let(:routes_file) do
      instance_double(Y2Network::SysconfigRoutesFile, save: nil, :routes= => nil)
    end

    let(:routes) { [route, default_route] }

    before do
      allow(Y2Network::SysconfigRoutesFile).to receive(:new)
        .with("/etc/sysconfig/network/ifroute-eth0")
        .and_return(ifroute_eth0)
      allow(Y2Network::SysconfigRoutesFile).to receive(:new)
        .with(no_args)
        .and_return(routes_file)
    end

    it "saves general routes to main routes file" do
      expect(routes_file).to receive(:routes=).with([default_route])
      expect(routes_file).to receive(:save)
      writer.write(config)
    end

    it "saves interface specific routes to the ifroute-* file" do
      expect(ifroute_eth0).to receive(:routes=).with([route])
      expect(ifroute_eth0).to receive(:save)
      writer.write(config)
    end

    context "when there are no general routes" do
      let(:routes) { [route] }

      it "removes the ifroute file" do
        expect(routes_file).to_not receive(:remove)
        expect(routes_file).to receive(:save)
        writer.write(config)
      end
    end

    context "when there are no routes for an specific interface" do
      let(:routes) { [default_route] }

      it "removes the ifroute file" do
        expect(ifroute_eth0).to receive(:remove)
        writer.write(config)
      end
    end

    context "When IPv4 forwarding is set" do
      let(:forward_ipv4) { true }

      it "Writes ip forwarding setup for IPv4" do
        allow(Yast::SCR).to receive(:Write)

        expect(Yast::SCR)
          .to receive(:Write)
          .with(Yast::Path.new(Y2Network::SysconfigPaths::SYSCTL_IPV4_PATH), "1")
        expect(Yast::SCR)
          .to receive(:Write)
          .with(Yast::Path.new(Y2Network::SysconfigPaths::SYSCTL_IPV6_PATH), "0")

        writer.write(config)
      end
    end

    context "When IPv6 forwarding is set" do
      let(:forward_ipv6) { true }

      it "Writes ip forwarding setup for IPv6" do
        allow(Yast::SCR).to receive(:Write)

        expect(Yast::SCR)
          .to receive(:Write)
          .with(Yast::Path.new(Y2Network::SysconfigPaths::SYSCTL_IPV4_PATH), "0")
        expect(Yast::SCR)
          .to receive(:Write)
          .with(Yast::Path.new(Y2Network::SysconfigPaths::SYSCTL_IPV6_PATH), "1")

        writer.write(config)
      end
    end
  end
end
