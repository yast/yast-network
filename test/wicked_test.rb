#!/usr/bin/env rspec

# Copyright (c) [2019] SUSE LLC
#
# All Rights Reserved.
#
# This program is free software; you can redistribute it and/or modify it
# under the terms of version 2 of the GNU General Public License as published
# by the Free Software Foundation.
#
# This program is distributed in the hope that it will be useful, but WITHOUT
# ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or
# FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License for
# more details.
#
# You should have received a copy of the GNU General Public License along
# with this program; if not, contact SUSE LLC.
#
# To contact SUSE LLC about this file by physical or electronic mail, you may
# find current contact information at www.suse.com.

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
      allow(Yast::SCR).to receive("Execute").and_return("stdout" => <<~WICKED_OUTPUT
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

  describe "#ibft_interfaces" do
    let(:stdout) { instance_double("Yast::Execute") }

    before do
      allow(Yast::Execute).to receive(:stdout).and_return(stdout)
      allow(stdout).to receive(:locally!).and_return("eth0.42 eth0\neth0.42 eth0\neth1")
    end

    it "returns an array of the interfaces configured by iBFT using the wicked iBFT extension" do
      expect(subject.ibft_interfaces).to eql(["eth0.42", "eth0", "eth1"])
    end
  end
end
