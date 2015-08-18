#!/usr/bin/env rspec

require_relative "test_helper"

require "yast"
require_relative "../src/clients/lan_auto"

describe Yast::LanAutoClient do
  describe "#main" do
    before do
      allow(Yast::WFM).to receive(:Args).with(no_args).and_return([func])
      allow(Yast::WFM).to receive(:Args).with(0).and_return(func)
    end

    context "when func is GetModified" do
      let(:func) { "GetModified" }

      it "returns true if LanItems.GetModified is true" do
        expect(Yast::LanItems).to receive(:GetModified).and_return(true)
        expect(subject.main).to eq(true)
      end

      it "returns false if LanItems.GetModified is false" do
        expect(Yast::LanItems).to receive(:GetModified).and_return(false)
        expect(subject.main).to eq(false)
      end
    end
  end
end
