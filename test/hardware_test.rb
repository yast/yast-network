#! /usr/bin/env rspec

require_relative "test_helper"

require "yast"

class HardwareTestClass
  def initialize
    Yast.include self, "network/lan/hardware.rb"
  end
end

describe "#validate_hw" do
  subject { HardwareTestClass.new }

  let(:valid_name) { "eth0" }
  let(:long_name) { "verylongcustomnicname123" }

  before(:each) do
    allow(Yast::UI).to receive(:SetFocus)
    expect(subject).to receive(:UsedNicName).and_return false
  end

  it "passes for valid names only" do
    allow(subject).to receive(:devname_from_hw_dialog).and_return valid_name

    expect(subject.validate_hw(nil, nil)).to be true
  end

  # bnc#991486
  it "fails for long names" do
    allow(subject).to receive(:devname_from_hw_dialog).and_return long_name

    expect(subject.validate_hw(nil, nil)).to be false
  end
end
