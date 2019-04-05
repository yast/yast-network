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
require "cwm/rspec"

require "y2network/route"
require "y2network/widgets/routing_table"
require "y2network/routing_table"

describe Y2Network::Widgets::RoutingTable do
  let(:routing_table) do
    Y2Network::RoutingTable.new([
                                  Y2Network::Route.new(to: IPAddr.new("127.0.0.1/24")),
                                  Y2Network::Route.new(to: :default)
                                ])
  end
  subject { described_class.new(routing_table) }

  before do
    allow(Yast::UI).to receive(:ChangeWidget)
  end

  include_examples "CWM::Table"

  describe "#selected_route" do
    it "returns Route object according to selected row in table" do
      allow(Yast::UI).to receive(:QueryWidget)
        .with(Id(subject.widget_id), :SelectedItems).and_return(Id(1))

      expect(subject.selected_route).to eq Y2Network::Route.new(to: :default)
    end
  end

  describe "#add_route" do
    it "appends the new route to the routing table" do
      route = Y2Network::Route.new(to: IPAddr.new("10.100.0.0/24"))
      subject.add_route(route)

      expect(routing_table.routes.last).to eq route
    end

    it "calls #redraw_table" do
      expect(subject).to receive(:redraw_table)

      route = Y2Network::Route.new(to: IPAddr.new("10.100.0.0/24"))
      subject.add_route(route)
    end
  end

  describe "#replace_route" do
    before do
      allow(Yast::UI).to receive(:QueryWidget)
        .with(Id(subject.widget_id), :SelectedItems).and_return(Id(0))
    end

    it "replaces currently selected route with new one" do
      route = Y2Network::Route.new(to: IPAddr.new("10.100.0.0/24"))
      expect { subject.replace_route(route) }.to_not change { routing_table.routes.size }

      expect(routing_table.routes.first).to eq route
    end

    it "calls #redraw_table" do
      expect(subject).to receive(:redraw_table)

      route = Y2Network::Route.new(to: IPAddr.new("10.100.0.0/24"))
      subject.replace_route(route)
    end
  end

  describe "#delete_route" do
    before do
      allow(Yast::UI).to receive(:QueryWidget)
        .with(Id(subject.widget_id), :SelectedItems).and_return(Id(0))
    end

    it "deletes currently selected route" do
      expect { subject.delete_route }.to change { routing_table.routes.size }.from(2).to(1)
    end

    it "calls #redraw_table" do
      expect(subject).to receive(:redraw_table)

      subject.delete_route
    end
  end

  describe "#redraw_table" do
    it "changes widget items with current routes of routing table" do
      routing_table.routes.delete_at(0)
      expect(Yast::UI).to receive(:ChangeWidget).with(Id(subject.widget_id), :Items, [anything])

      subject.redraw_table
    end
  end
end
