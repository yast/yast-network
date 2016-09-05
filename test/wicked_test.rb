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

describe "#bring_up" do
  let(:subject) { DummyNetwork.new }

  it "raises ArgumentError if dev names parameter is nil" do
    expect { subject.bring_up(nil) }.to raise_error("ArgumentError")
  end

  it "returns true if given device names are empty" do
    expect(subject.bring_up([])).to eql(true)
  end

  it "returns true if given devices bring up successfully" do
    expect(Yast::SCR).to receive(:Execute)
      .with(DummyNetwork::BASH_PATH, "wicked ifup eth0 eth1").and_return(0)

    expect(subject.bring_up(["eth0", "eth1"])).to eql(true)
  end
end

describe "bring_down" do
  let(:subject) { DummyNetwork.new }

  it "raises ArgumentError if dev names parameter is nil" do
    expect { subject.bring_down(nil) }.to raise_error("ArgumentError")
  end

  it "returns true if given device names are empty" do
    expect(subject.bring_down([])).to eql(true)
  end

  it "returns true if given devices bring down successfully" do
    expect(Yast::SCR).to receive(:Execute)
      .with(DummyNetwork::BASH_PATH, "wicked ifdown eth0 eth1").and_return(0)

    expect(subject.bring_down(["eth0", "eth1"])).to eql(true)
  end
end
