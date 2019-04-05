#!/usr/bin/env rspec

require_relative "../../test_helper.rb"
require "y2network/widgets/firewall_zone"

require "cwm/rspec"

describe Y2Network::Widgets::FirewallZone do
  let(:subject) { described_class.new("eth0") }
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

    it "selects the current zone from the list if it was cached" do
      subject.value = "custom"
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

    context "when the select zone widget does not exist" do
      before do
        allow(Yast::UI).to receive(:WidgetExists).and_return(false)
      end

      it "returns the cached value" do
        expect(subject.value).to eql(nil)
        subject.value = "external"
        expect(subject.value).to eql("external")
      end
    end
  end

  describe "#store" do
    before do
      allow(Yast::UI).to receive(:WidgetExists).and_return(true, false)
    end

    it "caches the current value" do
      expect(subject).to receive(:selected_zone).and_return("external")
      subject.store
      expect(subject).to_not receive(:selected_zone?)
      expect(subject.store).to eql("external")
    end
  end

  describe "#store_permanent" do
    before do
      subject.value = "custom"
    end

    context "when firewalld is not installed" do
      let(:installed?) { false }

      it "returns the cached value" do
        expect(subject.store_permanent).to eql("custom")
      end
    end

    context "when firewalld is installed" do
      context "but the firewall zone will not be managed by the ifcfg file" do
        let(:managed?) { false }

        it "returns the cached value" do
          expect(subject.store_permanent).to eql("custom")
        end
      end

      context "and the cached value is not equal to the firewalld interface zone" do
        it "modifies the interface permanent ZONE" do
          allow(subject).to receive(:current_zone).and_return("external")
          expect_any_instance_of(Y2Firewall::Firewalld::Interface).to receive(:zone=).with("custom")
          subject.store_permanent
        end
      end

      context "and the cached value is the same than the firewalld interface zone" do
        it "does not touch the interface permanent ZONE" do
          allow(subject).to receive(:current_zone).and_return("custom")
          expect_any_instance_of(Y2Firewall::Firewalld::Interface).to_not receive(:zone=)
          subject.store_permanent
        end
      end
    end
  end
end
