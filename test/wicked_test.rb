#!/usr/bin/env rspec

require_relative "test_helper"

require "yast"
require "network/wicked"

class DummyNetwork
  include Yast::Wicked
end

describe "#reload_config" do
  let(:subject) { DummyNetwork.new }

  it "raises ArgumentError if dev names parameter is nil" do
    expect { subject.reload_config(nil) }.to raise_error("ArgumentError")
  end

  it "returns true if given device names are empty" do
    expect(subject.reload_config([])).to eql(true)
  end

  it "returns true if given devices reload successfully" do
    expect(Yast::SCR).to receive(:Execute)
      .with(DummyNetwork::BASH_PATH, "wicked ifreload eth0 eth1").and_return(0)

    expect(subject.reload_config(["eth0", "eth1"])).to eql(true)
  end
end
