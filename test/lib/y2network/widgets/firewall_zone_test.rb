#!/usr/bin/env rspec

require_relative "../../../test_helper.rb"
require "y2network/widgets/firewall_zone"

require "cwm/rspec"

describe Y2Network::Widgets::FirewallZone do
  let(:subject) { described_class.new("eth0") }
  let(:firewalld) { Y2Firewall::Firewalld.instance }
  let(:firewall_zones) { [["", "Default"], ["custom", "custom"]] }
  let(:managed?) { true }
  let(:installed?) { true }

  before do
    allow(firewalld).to receive(:installed?).and_return(installed?)
    allow(subject).to receive(:firewall_zones).and_return(firewall_zones)
    allow(subject).to receive(:managed?).and_return(managed?)
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

    it "enables / disables the selection of zone" do
      allow(subject).to receive(:managed?).and_return(false, true)
      expect(subject).to receive(:enable_zones).with(false)
      subject.init
      expect(subject).to receive(:enable_zones).with(true)
      subject.init
    end
  end

  describe "#value" do
    before do
      allow(Yast::UI).to receive(:WidgetExists).and_return(true)
    end

    context "when the checkbox is not checked" do
      let(:managed?) { false }

      it "returns nil" do
        expect(subject.value).to eql(nil)
      end
    end

    context "when the checkbox is checked" do
      it "returns the selected element" do
        expect(subject).to receive(:selected_zone).and_return("")
        expect(subject.value).to eql("")
      end
    end

    context "when the checkbox widget does not exist" do
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
      expect(subject).to receive(:managed?).and_return(true)
      expect(subject).to receive(:selected_zone).and_return("external")
      subject.store
      expect(subject).to_not receive(:managed?)
      expect(subject.store).to eql("external")
    end
  end

  describe "#store_zone" do
    before do
      subject.value = "custom"
    end

    context "when firewalld is not installed" do
      let(:installed?) { false }

      it "returns the cached value" do
        expect(subject.store_zone).to eql("custom")
      end
    end

    context "when firewalld is installed" do
      context "but the firewall zone will not be managed by the ifcfg file" do
        let(:managed?) { false }

        it "returns the cached value" do
          expect(subject.store_zone).to eql("custom")
        end
      end

      context "and the cached value is not equal to the firewalld interface zone" do
        it "modifies the interface permanent ZONE" do
          allow(subject).to receive(:current_zone).and_return("external")
          expect_any_instance_of(Y2Firewall::Firewalld::Interface).to receive(:zone=).with("custom")
          subject.store_zone
        end
      end

      context "and the cached value is the same than the firewalld interface zone" do
        it "does not touch the interface permanent ZONE" do
          allow(subject).to receive(:current_zone).and_return("custom")
          expect_any_instance_of(Y2Firewall::Firewalld::Interface).to_not receive(:zone=)
          subject.store_zone
        end
      end
    end
  end

  describe "#handle" do
    it "returns nil" do
      expect(subject.handle("ID" => "fake_event")).to eql(nil)
    end

    context "when the checkbox is checked" do
      before do
        allow(subject).to receive(:managed?).and_return(true)
      end

      it "enables the zone list selection" do
        expect(subject).to receive(:enable_zones).with(true)
        subject.handle("ID" => :manage_zone)
      end
    end

    context "then the checkbox is unchecked" do
      before do
        allow(subject).to receive(:managed?).and_return(false)
      end

      it "disables the zone list selection when not checked" do
        expect(subject).to receive(:enable_zones).with(false)
        subject.handle("ID" => :manage_zone)
      end
    end
  end
end
