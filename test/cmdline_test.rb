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
end
