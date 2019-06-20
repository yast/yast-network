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

require_relative "../../test_helper"
require "y2network/sysconfig/interface_file"

describe Y2Network::Sysconfig::InterfaceFile do
  subject(:file) { described_class.new("eth0") }

  let(:scr_root) { File.join(DATA_PATH, "scr_read") }

  around do |example|
    change_scr_root(scr_root, &example)
  end

  describe ".find" do
    it "returns an object representing the file" do
      file = described_class.find("eth0")
      expect(file).to be_a(described_class)
      expect(file.name).to eq("eth0")
    end

    context "when a file for the given interface does not exist" do
      it "returns nil" do
        expect(described_class.find("em1")).to be_nil
      end
    end
  end

  describe "#fetch" do
    it "returns the raw value from the sysconfig file" do
      expect(file.fetch("IPADDR")).to eq("192.168.123.1/24")
    end

  end

  describe "#ip_address" do
    let(:ipaddr) { "192.168.122.122/24" }

    before do
      allow(file).to receive(:fetch).with("IPADDR").and_return(ipaddr)
    end

    it "returns the IP address" do
      expect(file.ip_address).to eq(IPAddr.new(ipaddr))
    end

    context "when the IP address is not defined" do
      let(:ipaddr) { "" }

      it "returns nil" do
        expect(file.ip_address).to be_nil
      end
    end
  end

  describe "#bootproto" do
    let(:bootproto) { "static" }

    it "returns the bootproto as a symbol" do
      expect(file.bootproto).to eq(:static)
    end
  end

  describe "#startmode" do
    let(:startmode) { "auto" }

    it "returns the startmode as a symbol" do
      expect(file.startmode).to eq(:auto)
    end
  end

  describe "#wireless_keys" do
    subject(:file) { described_class.new("wlan0") }

    it "returns the list of keys" do
      expect(file.wireless_keys).to eq(["0-1-2-3-4-5", "s:password"])
    end
  end
end
