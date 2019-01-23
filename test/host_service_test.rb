#!/usr/bin/env rspec

require_relative "test_helper"

Yast.import "UI"

class DummyHostService < Yast::Module
  def initialize
    Yast.include self, "network/services/host.rb"
  end
end

describe "NetworkServicesHostInclude" do
  subject { DummyHostService.new }

  describe "#encode_hosts_line" do
    it "encodes canonical name even aliases" do
      canonical = "žížala.jůlinka.go.home"
      aliases = "žížala jůlinka	earthworm"

      result = subject.encode_hosts_line(canonical, aliases.split)

      expect(result).to eql "xn--ala-qma83eb.xn--jlinka-3mb.go.home xn--ala-qma83eb xn--jlinka-3mb earthworm"
    end

    it "returns empty string when invalid arguments were passed" do
      result = subject.encode_hosts_line(nil, nil)

      expect(result).to be_empty
    end
  end
end
