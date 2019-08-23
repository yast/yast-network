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

require_relative "../../test_helper.rb"
require "y2network/widgets/firewall_zone"
require "y2network/interface_config_builder"

require "cwm/rspec"

describe Y2Network::Widgets::FirewallZone do
  let(:builder) do
    res = Y2Network::InterfaceConfigBuilder.for("eth")
    res.name = "eth0"
    res
  end
  subject { described_class.new(builder) }

  let(:firewalld) { Y2Firewall::Firewalld.instance }
  let(:firewall_zones) { [["", "Default"], ["custom", "custom"]] }
  let(:installed?) { true }

  before do
    allow(firewalld).to receive(:installed?).and_return(installed?)
    allow(subject).to receive(:firewall_zones).and_return(firewall_zones)
  end

  include_examples "CWM::CustomWidget"

  describe "#init" do
    it "populates the zones list with the firewalld zones" do
      expect(subject).to receive(:populate_select).with(firewall_zones)
      subject.init
    end

    it "selects the current zone" do
      builder.firewall_zone = "custom"
      expect(subject).to receive(:select_zone).with("custom")
      subject.init
    end
  end

  describe "#value" do
    before do
      allow(Yast::UI).to receive(:WidgetExists).and_return(true)
    end

    it "returns the selected element" do
      expect(subject).to receive(:selected_zone).and_return("")
      expect(subject.value).to eql("")
    end
  end

  describe "#store" do
    it "stores value to builder" do
      allow(subject).to receive(:selected_zone).and_return("external")
      subject.store
      expect(builder.firewall_zone).to eq "external"
    end
  end
end
