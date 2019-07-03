#!/usr/bin/env rspec

require_relative "test_helper"

class DummyClass < Yast::Module
  def initialize
    Yast.include self, "network/lan/cmdline.rb"
  end
end

describe "NetworkLanCmdlineInclude" do
  subject { DummyClass.new }

  describe "#ShowHandler" do
    it "creates plain text from formatted html" do
      richtext = "test<br><ul><li>item1</li><li>item2</li></ul>"
      allow(subject).to receive(:getConfigList).and_return(["0" => { "rich_descr" => richtext }])

      expect(Yast::CommandLine).to receive(:Print).with("test\nitem1\nitem2\n\n")

      expect(subject.ShowHandler("id" => "0")).to eq true
    end
  end

  describe "AddHandler" do
    let(:options) { { "name" => "vlan0", "ethdevice" => "eth0", "bootproto" => "dhcp" } }

    before do
      allow(Yast::Report).to receive(:Error)
      allow(Yast::LanItems).to receive(:Commit)
    end

    context "when called without type" do
      let(:no_type_options) { options.reject { |k| k == "ethdevice" } }

      context "and it cannot be infered from the given options" do
        it "reports an error" do
          expect(Yast::Report).to receive(:Error)
          subject.AddHandler(no_type_options)
        end

        it "returns false" do
          expect(subject.AddHandler(no_type_options)).to eq false
        end
      end
    end

    context "when startmode is given" do
      context "but with an invalid option" do
        it "reports an error" do
          expect(Yast::Report).to receive(:Error)
          subject.AddHandler(options.merge("startmode" => "wrong"))
        end

        it "returns false" do
          expect(subject.AddHandler(options.merge("startmode" => "wrong"))).to eq false
        end
      end
    end

    context "when a valid configuration is providen" do
      before do
        allow(subject).to receive(:ListHandler)
      end

      it "commits the new configuration" do
        expect(Yast::LanItems).to receive(:Commit)
        subject.AddHandler(options)
      end

      it "lists the final configuration" do
        expect(subject).to receive(:ListHandler)
        subject.AddHandler(options)
      end

      it "returns true" do
        expect(Yast::Report).to_not receive(:Error)
        expect(subject.AddHandler(options)).to eq true
      end
    end
  end
end
