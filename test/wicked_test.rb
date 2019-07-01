#!/usr/bin/env rspec

require_relative "test_helper"

require "yast"
require "network/wicked"

class DummyNetwork
  include Yast::Wicked
end

describe Yast::Wicked do
  subject { DummyNetwork.new }
  describe "#reload_config" do

    it "raises ArgumentError if dev names parameter is nil" do
      expect { subject.reload_config(nil) }.to raise_error("ArgumentError")
    end

    it "returns true if given device names are empty" do
      expect(subject.reload_config([])).to eql(true)
    end

    it "returns true if given devices reload successfully" do
      expect(Yast::SCR).to receive(:Execute)
        .with(DummyNetwork::BASH_PATH, "/usr/sbin/wicked ifreload eth0 eth1").and_return(0)

      expect(subject.reload_config(["eth0", "eth1"])).to eql(true)
    end
  end

  describe "#parse_ntp_servers" do
    before do
      allow(Yast::NetworkService).to receive(:is_wicked).and_return(true)
      allow(::File).to receive(:file?).and_return(true, false)
      allow(Yast::SCR).to receive("Execute").and_return("stdout" => <<WICKED_OUTPUT
10.100.2.10
10.100.2.11
10.100.2.12
WICKED_OUTPUT
      )
    end

    it "returns list of ntp servers defined in dhcp lease" do
      expect(subject.parse_ntp_servers("eth0")).to eq(["10.100.2.10", "10.100.2.11", "10.100.2.12"])
    end
  end
end
