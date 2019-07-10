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
require "tmpdir"

describe Y2Network::Sysconfig::InterfaceFile do
  subject(:file) { described_class.new("eth0") }

  def file_content(scr_root, file)
    path = File.join(scr_root, file.path.to_s)
    File.read(path)
  end

  let(:scr_root) { Dir.mktmpdir }

  around do |example|
    begin
      FileUtils.cp_r(File.join(DATA_PATH, "scr_read", "etc"), scr_root)
      change_scr_root(scr_root, &example)
    ensure
      FileUtils.remove_entry(scr_root)
    end
  end

  describe ".find" do
    it "returns an object representing the file" do
      file = described_class.find("eth0")
      expect(file).to be_a(described_class)
      expect(file.interface).to eq("eth0")
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

    context "when the IP address is empty" do
      let(:ipaddr) { "" }

      it "returns nil" do
        expect(file.ip_address).to be_nil
      end
    end

    context "when the IP address is undefined" do
      let(:ipaddr) { nil }

      it "returns nil" do
        expect(file.ip_address).to be_nil
      end
    end
  end

  describe "#ipaddr=" do
    it "sets the bootproto" do
      expect { file.ipaddr = IPAddr.new("10.0.0.1") }
        .to change { file.ipaddr }.to(IPAddr.new("10.0.0.1"))
    end
  end

  describe "#bootproto" do
    let(:bootproto) { "static" }

    it "returns the bootproto as a symbol" do
      expect(file.bootproto).to eq(:static)
    end
  end

  describe "#bootproto=" do
    it "sets the bootproto" do
      expect { file.bootproto = :dhcp }.to change { file.bootproto }.from(:static).to(:dhcp)
    end
  end

  describe "#startmode" do
    let(:startmode) { "auto" }

    it "returns the startmode as a symbol" do
      expect(file.startmode).to eq(:auto)
    end
  end

  describe "#startmode=" do
    it "sets the startmode" do
      expect { file.startmode = :manual }.to change { file.startmode }.from(:auto).to(:manual)
    end
  end

  describe "#wireless_keys" do
    subject(:file) { described_class.new("wlan0") }

    it "returns the list of keys" do
      expect(file.wireless_keys).to eq(["0-1-2-3-4-5", "s:password"])
    end
  end

  describe "#wireless_keys=" do
    let(:keys) { ["123456", "abcdef"] }

    it "sets the wireless keys" do
      expect { file.wireless_keys = keys }.to change { file.wireless_keys }.to(keys)
    end
  end

  describe "#save" do
    subject(:file) { described_class.new("eth0") }

    it "writes the changes to the file" do
      file.ipaddr = Y2Network::IPAddress.from_string("192.168.122.1/24")
      file.bootproto = :static
      file.save

      content = file_content(scr_root, file)
      expect(content).to include("BOOTPROTO='static'")
      expect(content).to include("IPADDR='192.168.122.1/24'")
    end

    describe "when multiple wireless keys are specified" do
      it "writes indexes keys" do
        file.wireless_keys = ["123456", "abcdef"]
        file.save

        content = file_content(scr_root, file)
        expect(content).to include("WIRELESS_KEY_0='123456")
        expect(content).to include("WIRELESS_KEY_1='abcdef")
      end
    end

    describe "when a nil value is specified" do
      it "removes the key from the value" do
        file.bootproto = nil
        file.save

        content = file_content(scr_root, file)
        expect(content).to_not include("BOOTPROTO")
      end
    end
  end

  describe "#clean" do
    subject(:file) { described_class.new("eth0") }

    it "removes all known values from the file" do
      file.clean
      file.save

      content = file_content(scr_root, file)
      expect(content).to include("BROADCAST=''")
    end
  end
end
