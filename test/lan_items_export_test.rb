#!/usr/bin/env rspec

require_relative "test_helper"

require "yast"

Yast.import "LanItems"
Yast.import "Arch"

describe "LanItemsClass#export_udevs" do
  subject { Yast::LanItems }

  let(:devices) do
    {
      "eth" => {
        "eth0" => {}
      }
    }
  end

  let(:scr) { Yast::SCR }

  before(:each) do
    # mock SCR to not touch system
    allow(scr).to receive(:Read).and_return("")
    allow(scr).to receive(:Execute).and_return("exit" => -1, "stdout" => "", "stderr" => "")
  end

  def path(p)
    Yast::Path.new(p)
  end

  context "When running on s390" do
    before(:each) do
      allow(Yast::Arch).to receive(:s390).and_return(true)
    end

    # kind of smoke test
    it "produces s390 specific content in exported AY profile" do
      allow(scr)
        .to receive(:Execute)
        .with(path(".target.bash_output"), /^driver=.*/)
        .and_return("exit" => 0, "stdout" => "qeth", "stderr" => "")

      ay = subject.send(:export_udevs, devices)

      expect(ay["s390-devices"]).not_to be_empty
      # check if the export builds correct map
      expect(ay["s390-devices"]["eth0"]["type"]).to eql "qeth"
    end
  end
end
