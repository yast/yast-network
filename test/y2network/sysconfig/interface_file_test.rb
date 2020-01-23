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
  subject(:file) { described_class.new(interface_name).tap(&:load) }

  let(:interface_name) { "eth0" }

  def file_content(scr_root, file)
    path = File.join(scr_root, file.path.to_s)
    File.read(path)
  end

  let(:scr_root) { Dir.mktmpdir }

  around do |example|

    FileUtils.cp_r(File.join(DATA_PATH, "scr_read", "etc"), scr_root)
    change_scr_root(scr_root, &example)
  ensure
    FileUtils.remove_entry(scr_root)

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

  describe ".all" do
    it "returns all the present interfaces files" do
      files = described_class.all
      expect(files).to be_all(Y2Network::Sysconfig::InterfaceFile)
      interfaces = files.map(&:interface)
      expect(interfaces).to include("wlan0")
    end
  end

  describe "#exist?" do
    subject(:file) { described_class.new(interface) }

    context "when the file for the given interface exists" do
      let(:interface) { "eth0" }

      it "returns true" do
        expect(file.exist?).to eq(true)
      end
    end

    context "when the file for the given interface does not exist" do
      let(:interface) { "em1" }

      it "returns false" do
        expect(file.exist?).to eq(false)
      end
    end
  end

  describe "#remove" do
    subject(:file) { described_class.find("eth0") }

    it "removes the file" do
      expect(file).to_not be_nil
      file.remove
      expect(File).to_not exist(File.join(scr_root, file.path))
    end
  end

  describe "#ipaddrs" do
    it "returns the IP addresses" do
      expect(file.ipaddrs).to eq(
        "" => Y2Network::IPAddress.from_string("192.168.123.1/24")
      )
    end

    context "when multiple addresses are defined" do
      let(:interface_name) { "eth1" }

      it "returns a hash with IP addresses indexed by their suffixes" do
        expect(file.ipaddrs).to eq(
          "_0" => Y2Network::IPAddress.from_string("192.168.123.1/24"),
          "_1" => Y2Network::IPAddress.from_string("10.0.0.1")
        )
      end
    end

    context "when the IP address is missing" do
      let(:interface_name) { "eth4" }

      it "returns an empty hash" do
        expect(file.ipaddrs).to be_empty
      end
    end
  end

  describe "#ipaddrs=" do
    let(:interface_name) { "eth4" }

    it "sets the bootproto" do
      addresses = { default: Y2Network::IPAddress.from_string("10.0.0.1") }
      expect { file.ipaddrs = addresses }
        .to change { file.ipaddrs }.from({}).to(addresses)
    end
  end

  describe "#bootproto" do
    let(:bootproto) { "static" }

    it "returns the bootproto as a string" do
      expect(file.bootproto).to eq("static")
    end
  end

  describe "#bootproto=" do
    it "sets the bootproto" do
      expect { file.bootproto = "dhcp" }.to change { file.bootproto }.from("static").to("dhcp")
    end
  end

  describe "#mtu" do
    let(:mtu) { "1500" }

    it "returns the MTU as a string" do
      expect(file.mtu).to eq("1500")
    end
  end

  describe "#mtu=" do
    it "sets the MTU" do
      expect { file.mtu = "1234" }.to change { file.mtu }.from("1500").to("1234")
    end
  end

  describe "#startmode" do
    let(:startmode) { "auto" }

    it "returns the startmode as a string" do
      expect(file.startmode).to eq("auto")
    end
  end

  describe "#startmode=" do
    it "sets the startmode" do
      expect { file.startmode = "manual" }.to change { file.startmode }.from("auto").to("manual")
    end
  end

  describe "#wireless_keys" do
    let(:interface_name) { "wlan2" }

    it "returns the list of keys" do
      expect(file.wireless_keys).to eq("_0" => "0-1-2-3-4-5", "_1" => "s:password")
    end
  end

  describe "#wireless_keys=" do
    let(:keys) { { default: "123456", "_1" => "abcdef" } }

    it "sets the wireless keys" do
      expect { file.wireless_keys = keys }.to change { file.wireless_keys }.to(keys)
    end
  end

  describe "#save" do
    subject(:file) { described_class.new("eth0") }

    it "writes the changes to the file" do
      file.ipaddrs = { default: Y2Network::IPAddress.from_string("192.168.122.1/24") }
      file.bootproto = :static
      file.save

      content = file_content(scr_root, file)
      expect(content).to include("BOOTPROTO='static'")
      expect(content).to include("IPADDR='192.168.122.1/24'")
    end

    describe "when multiple wireless keys are specified" do
      it "writes indexes keys" do
        file.wireless_keys = { "" => "123456", "_1" => "abcdef" }
        file.save

        content = file_content(scr_root, file)
        expect(content).to include("WIRELESS_KEY='123456")
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
    let(:interface_name) { "eth1" }

    it "removes all known values from the file" do
      file.clean
      file.save

      content = file_content(scr_root, file)
      expect(content).to_not include("IPADDR_0")
    end
  end

  describe "#type" do
    it "determines the interface type from the attributes" do
      file.interfacetype = "dummy"
      expect(file.type.short_name).to eql("dummy")
      file.interfacetype = nil
      file.tunnel = "tap"
      expect(file.type.short_name).to eql("tap")
    end
  end
end
