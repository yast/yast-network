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

require_relative "../../test_helper"
require "y2network/clients/routing"
require "y2network/routing"
require "y2network/routing_table"

describe Y2Network::Clients::Routing do
  let(:args) { [] }
  let(:serializer) do
    Y2Network::Serializer::RouteSysconfig.new
  end

  let(:route) do
    serializer.from_hash("destination" => "default", "gateway" => "192.168.1.1")
  end

  let(:table) { Y2Network::RoutingTable.new([route]) }
  let(:config) { Y2Network::Config.new(interfaces: [], routing: routing, source: :sysconfig) }
  let(:routing) { Y2Network::Routing.new(tables: [table], forward_ipv4: true, forward_ipv6: false) }

  before do
    allow(Yast::WFM).to receive(:Args).and_return(args)
    allow(subject).to receive(:write).and_return(true)
    allow(subject).to receive(:read).and_return(true)
    allow(subject).to receive(:yast_config).and_return(config)
    allow(Yast::CommandLine).to receive(:Print)
  end

  describe "#main" do
    it "runs the routing cmdline client" do
      allow(subject).to receive(:RoutingGUI)
      expect(subject).to receive(:cmdline_definition)
      subject.main
    end

    context "when calling with no ARGS" do
      it "runs the GUI dialog" do
        expect(subject).to receive(:RoutingGUI)
        subject.main
      end
    end

    context "when calling with 'list'" do
      let(:args) { ["list"] }
      it "prints the list of the configured routes" do
        expect(Yast::CommandLine).to receive(:Print).with(/Routing Table/)
        subject.main
      end
    end

    context "when calling with 'show'" do
      let(:args) { ["show"] }

      context "and do not specify a dest target" do
        it "prints and error" do
          expect(Yast::CommandLine).to receive(:Print).with(/No entry for/)
          subject.main
        end
      end

      context "with an existent route destination" do
        let(:args) { ["show", "dest=default"] }

        it "prints the routes for the given destination" do
          expect(Yast::CommandLine).to receive(:Print).with(/default[\s]+192.168.1.1[\s]+-[\s]+-/)
          subject.main
        end
      end
    end

    context "when calling with 'add'" do
      let(:args) { ["add"] }

      context "and do not specify a dest target" do
        it "prints and error" do
          expect(Yast::CommandLine).to receive(:Print).with(/At least destination/)
          subject.main
        end
      end

      context "with at least a route destination" do
        let(:args) { ["add", "dest=192.168.1.0", "gateway=192.168.1.1", "netmask=255.255.255.0"] }

        it "adds the new route" do
          expect(routing.routes.size).to eq(1)
          subject.main
          expect(routing.routes.size).to eq(2)
        end
      end
    end
    context "when calling with 'delete'" do
      let(:args) { ["delete"] }

      context "and do not specify a dest target" do
        it "prints and error" do
          expect(Yast::CommandLine).to receive(:Print).with(/No entry for/)
          subject.main
        end
      end

      context "with an existent route destination" do
        let(:args) { ["delete", "dest=default"] }

        it "deletes the routes with the given destination" do
          expect(routing.routes.size).to eq(1)
          subject.main
          expect(routing.routes.size).to eq(0)
        end
      end
    end

    context "when called with 'ip-forwarding'" do
      context "and with 'show' parameter" do
        let(:args) { ["ip-forwarding", "show"] }

        it "prints ipv4 and ipv6 configuration" do
          expect(Yast::CommandLine).to receive(:Print).with(/IPv4 and IPv6 Forwarding:/)
          expect(Yast::CommandLine).to receive(:Print).with("IPv4 forwarding is enabled")
          expect(Yast::CommandLine).to receive(:Print).with("IPv6 forwarding is disabled")
          subject.main
        end
      end
    end

    context "when called with 'ipv4-forwarding'" do
      context "and with 'show' parameter" do
        let(:args) { ["ipv4-forwarding", "show"] }

        it "prints IPv4 configuration" do
          expect(Yast::CommandLine).to receive(:Print).with(/IPv4 Forwarding:/)
          expect(Yast::CommandLine).to receive(:Print).with("IPv4 forwarding is enabled")
          subject.main
        end
      end

      context "and with 'off' parameter" do
        let(:args) { ["ipv4-forwarding", "off"] }

        it "disables IPv4 forwarding" do
          expect(routing.forward_ipv4).to eq(true)
          subject.main
          expect(routing.forward_ipv4).to eq(false)
        end
      end

      context "and with 'on' parameter" do
        let(:args) { ["ipv4-forwarding", "on"] }
        before do
          routing.forward_ipv4 = false
        end

        it "enables IPv4 forwarding" do
          expect(routing.forward_ipv4).to eql(false)
          subject.main
          expect(routing.forward_ipv4).to eql(true)
        end
      end
    end

    context "when called with 'ipv6-forwarding'" do
      context "and with 'show' parameter" do
        let(:args) { ["ipv6-forwarding", "show"] }

        it "prints IPv6 configuration" do
          expect(Yast::CommandLine).to receive(:Print).with(/IPv6 Forwarding:/)
          expect(Yast::CommandLine).to receive(:Print).with("IPv6 forwarding is disabled")
          subject.main
        end
      end

      context "and with 'off' parameter" do
        let(:args) { ["ipv6-forwarding", "off"] }
        before do
          routing.forward_ipv6 = true
        end

        it "disables IPv6 forwarding" do
          expect(routing.forward_ipv6).to eq(true)
          subject.main
          expect(routing.forward_ipv6).to eq(false)
        end
      end

      context "and with 'on' parameter" do
        let(:args) { ["ipv6-forwarding", "on"] }

        it "enables IPv6 forwarding" do
          expect(routing.forward_ipv6).to eql(false)
          subject.main
          expect(routing.forward_ipv6).to eql(true)
        end
      end
    end
  end
end
