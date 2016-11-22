#!/usr/bin/env rspec

require_relative "test_helper"

Yast.import "Report"

class NetworkLanCmdlineIncludeClass < Yast::Module
  def initialize
    Yast.include self, "network/lan/cmdline.rb"
  end
end

describe "Yast::NetworkLanCmdlineInclude" do
  subject { NetworkLanCmdlineIncludeClass.new }

  describe "#validateId" do
    it "reports error and returns false if options missing \"id\"" do
      expect(Yast::Report).to receive(:Error)

      expect(subject.validateId({}, [])).to eq false
    end

    it "reports error and returns false if options \"id\" is not number" do
      expect(Yast::Report).to receive(:Error)

      expect(subject.validateId({ "id" => "zzz" }, [])).to eq false
    end

    it "reports error and returns false if options \"id\" do not fit config size" do
      expect(Yast::Report).to receive(:Error)

      expect(subject.validateId({ "id" => "5" }, [])).to eq false
    end

    it "returns true otherwise" do
      expect(Yast::Report).to_not receive(:Error)

      expect(subject.validateId({ "id" => "0" }, ["0" => { "id" => "0" }])).to eq true
    end

  end
end
