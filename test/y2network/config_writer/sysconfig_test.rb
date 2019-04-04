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
require "y2network/config_writer/sysconfig_routes_writer"
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
    let(:forward_ipv4) { false }
    let(:forward_ipv6) { false }
    let(:routing) do
      Y2Network::Routing.new(
        tables: [Y2Network::RoutingTable.new([route])],
        forward_ipv4: forward_ipv4,
        forward_ipv6: forward_ipv6
      )
    end

    it "Creates writer for ifroute file" do
      sysconfig_writer = instance_double(Y2Network::ConfigWriter::SysconfigRoutesWriter)

      expect(Y2Network::ConfigWriter::SysconfigRoutesWriter)
        .to receive(:new)
        .with(routes_file: "/etc/sysconfig/network/ifroute-eth0")
        .and_return(sysconfig_writer)
      expect(sysconfig_writer)
        .to receive(:write)

      writer.write(config)
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

    context "when routes elements are not defined" do
      let(:route) do
        Y2Network::Route.new(to: :default, interface: :any)
      end

      it "Creates writer for global /etc/sysconfig/network/routes file if route's device is not set" do
        sysconfig_writer = instance_double(Y2Network::ConfigWriter::SysconfigRoutesWriter)

        expect(Y2Network::ConfigWriter::SysconfigRoutesWriter)
          .to receive(:new)
          .with(no_args)
          .and_return(sysconfig_writer)
        expect(sysconfig_writer)
          .to receive(:write)

        writer.write(config)
      end
    end
  end
end
