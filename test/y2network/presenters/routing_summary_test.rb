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
require "y2network/presenters/routing_summary"
require "y2network/config"
require "y2network/routing"
require "y2network/routing_table"
require "y2network/route"

describe Y2Network::Presenters::RoutingSummary do
  subject(:presenter) { described_class.new(routing) }

  let(:routing) do
    Y2Network::Routing.new(tables: [table], forward_ipv4: true, forward_ipv6: false)
  end
  let(:table) do
    Y2Network::RoutingTable.new([default_route])
  end
  let(:default_route) { Y2Network::Route.new(to: :default, gateway: IPAddr.new("10.0.0.1")) }
  let(:gw_hostname) { "gw.example.net" }

  before do
    allow(Yast::NetHwDetection).to receive(:ResolveIP).with("10.0.0.1")
      .and_return(gw_hostname)
  end

  describe "#text" do
    it "returns a summary in text form" do
      text = presenter.text
      expect(text).to include("10.0.0.1 (gw.example.net)")
      expect(text).to include("IP Forwarding for IPv4: on")
      expect(text).to include("IP Forwarding for IPv6: off")
    end

    context "when no default route is defined" do
      let(:table) do
        Y2Network::RoutingTable.new([])
      end
      it "does not include the gateway" do
        expect(presenter.text).to_not include("Gateways")
      end
    end

    context "when it is not possible to resolve the gateway hostname" do
      let(:gw_hostname) { "" }

      it "only includes the gateway IP" do
        expect(presenter.text).to include("<li>10.0.0.1</li>")
      end
    end

    context "when there is no routing configuration" do
      let(:routing) { nil }

      it "returns an empty string" do
        expect(presenter.text).to eq("")
      end
    end

    context "when there are no routes" do
      let(:routing) { instance_double(Y2Network::Routing, routes: []) }

      it "returns an empty string" do
        expect(presenter.text).to eq("")
      end
    end
  end
end
