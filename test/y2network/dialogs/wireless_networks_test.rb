# Copyright (c) [2021] SUSE LLC
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
require "y2network/dialogs/wireless_networks"
require "y2network/widgets/wireless_networks"
require "y2network/wireless_network"
require "cwm/rspec"

describe Y2Network::Dialogs::WirelessNetworks do
  subject { described_class.new(builder) }

  include_examples "CWM::CustomWidget"

  let(:builder) { Y2Network::InterfaceConfigBuilder.for("wlan") }

  let(:networks_table) do
    Y2Network::Widgets::WirelessNetworks.new(builder)
  end

  let(:selected) do
    instance_double(Y2Network::WirelessNetwork, essid: "TESTING")
  end

  let(:interface) do
    Y2Network::PhysicalInterface.new("wlo1")
  end

  before do
    allow(Y2Network::Widgets::WirelessNetworks).to receive(:new)
      .and_return(networks_table)
    allow(Y2Network::WirelessNetwork).to receive(:all).with("wlo1", cache: true)
      .and_return([selected])
    allow(networks_table).to receive(:selected).and_return(selected)
    allow(networks_table).to receive(:update)
    allow(Yast2::Feedback).to receive(:show) { |&block| block.call }
    allow(builder).to receive(:interface).and_return(interface)
    allow(networks_table).to receive(:init)
  end

  describe "#run" do
    before do
      allow(Yast::UI).to receive(:WaitForEvent).and_return(event)
    end

    context "if the user clicks the 'Select' button" do
      let(:event) { { "ID" => :ok, "EventReason" => "Activated" } }

      it "returns the selected network" do
        expect(subject.run).to eq(selected)
      end
    end

    context "if the user clicks the 'Cancel' button" do
      let(:event) { { "ID" => :cancel, "EventReason" => "Activated" } }

      it "returns nil" do
        expect(subject.run).to eq(nil)
      end
    end
  end
end
