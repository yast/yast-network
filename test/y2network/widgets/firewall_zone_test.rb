#!/usr/bin/env rspec

require_relative "../../test_helper.rb"
require "y2network/widgets/firewall_zone"
require "y2network/interface_config_builder"

require "cwm/rspec"

describe Y2Network::Widgets::FirewallZone do
  let(:builder) do
    res = Y2Network::InterfaceConfigBuilder.new
    res.type = "eth"
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
