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
require "y2network/autoinst_profile/networking_section"
require "y2network/config"

describe Y2Network::AutoinstProfile::NetworkingSection do
  describe ".new_from_network" do
    let(:config) do
      Y2Network::Config.new(interfaces: [], routing: routing, source: :sysconfig)
    end
    let(:routing) { double("Y2Network::Routing") }
    let(:routing_section) { double("RoutingSection") }

    before do
      allow(Y2Network::AutoinstProfile::RoutingSection).to receive(:new_from_network)
        .with(routing).and_return(routing_section)
    end

    it "initializes the routing section" do
      section = described_class.new_from_network(config)
      expect(section.routing).to eq(routing_section)
    end
  end

  describe ".new_from_hashes" do
    let(:hash) do
      {
        "routing" => routing
      }
    end
    let(:routing) { {} }
    let(:routing_section) { double("RoutingSection") }

    before do
      allow(Y2Network::AutoinstProfile::RoutingSection).to receive(:new_from_hashes)
        .with(routing).and_return(routing_section)
    end

    it "initializes the routing section" do
      section = described_class.new_from_hashes(hash)
      expect(section.routing).to eq(routing_section)
    end

    context "when no routing section is present" do
      let(:routing) { nil }

      it "does not initialize the routing section" do
        section = described_class.new_from_hashes(hash)
        expect(section.routing).to eq(nil)
      end
    end
  end
end
