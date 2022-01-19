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

require "y2network/widgets/bond_port"
require "y2network/interface_config_builders/bonding"

describe Y2Network::Widgets::BondSlave do
  let(:builder) { Y2Network::InterfaceConfigBuilders::Bonding.new }
  subject { described_class.new(builder) }

  before do
    allow(builder).to receive(:yast_config).and_return(Y2Network::Config.new(source: :testing))
  end

  include_examples "CWM::CustomWidget"

  describe "#validate" do
    before do
      allow(subject).to receive(:selected_items)
        .and_return(items)
    end

    context "when there is not more than one physical port id per interface" do
      let(:items) { ["eth0", "eth1", "eth2", "eth3"] }

      it "returns true" do
        allow(subject).to receive(:physical_port_id?).with("eth0").and_return(false)
        allow(subject).to receive(:physical_port_id?).with("eth1").and_return(false)
        allow(subject).to receive(:physical_port_id?).with("eth2").and_return(true)
        allow(subject).to receive(:physical_port_id?).with("eth3").and_return(true)
        allow(subject).to receive(:physical_port_id).with("eth2").and_return("00010486fd348")
        allow(subject).to receive(:physical_port_id).with("eth3").and_return("00010486fd34a")

        expect(subject.validate).to eql(true)
      end
    end

    context "when there is more than one physical port id per interface" do
      let(:items) do
        ["eth0", "eth1", "eth2", "eth3", "eth4", "eth5", "eth6", "eth7",
         "enp0sp25", "enp0sp26", "enp0sp27", "enp0sp28", "enp0sp29"]
      end

      it "warns the user and request confirmation to continue" do
        items.map do |i|
          allow(subject).to receive(:physical_port_id?).with(i).and_return(true)
          allow(subject).to receive(:physical_port_id).with(i).and_return("00010486fd348")
        end

        expect(Yast::Popup).to receive(:YesNoHeadline).and_return(false)

        expect(subject.validate).to eql(false)
      end
    end
  end
end
