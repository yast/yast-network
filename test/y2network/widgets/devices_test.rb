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
require "y2network/route"
require "y2network/interface"
require "y2network/widgets/devices"

require "cwm/rspec"

describe Y2Network::Widgets::Devices do
  let(:route) { Y2Network::Route.new }
  subject { described_class.new(route, ["eth0", "lo"]) }

  include_examples "CWM::ComboBox"

  describe "#init" do
    context "route contain specific interface" do
      let(:route) { Y2Network::Route.new(interface: Y2Network::Interface.new("lo")) }

      it "is selected" do
        expect(subject).to receive(:value=).with("lo")

        subject.init
      end
    end
  end

  describe "#store" do
    context "specific interface is selected" do
      it "is stored to route" do
        expect(subject).to receive(:value).and_return("eth0")

        subject.store

        expect(route.interface.name).to eq "eth0"
      end
    end
  end
end
