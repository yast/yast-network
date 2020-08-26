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
require "y2network/autoinst_profile/s390_device_section"
require "y2network/connection_config/ip_config"

describe Y2Network::AutoinstProfile::S390DeviceSection do
  subject(:section) { described_class.new }

  describe ".new_from_network" do
    let(:config) do
      Y2Network::ConnectionConfig::Qeth.new.tap do |c|
        c.bootproto = Y2Network::BootProtocol::STATIC
        c.firewall_zone = "public"
        c.interface = "eth0"
        c.ip = Y2Network::ConnectionConfig::IPConfig.new(
          Y2Network::IPAddress.from_string("10.100.0.1/24")
        )
        # s390 specific
        c.read_channel = "0.0.0700"
        c.write_channel = "0.0.0701"
        c.data_channel = "0.0.0702"
        c.layer2 = true
        c.port_number = "0"
      end
    end

    let(:parent) { double("Installation::AutoinstProfile::SectionWithAttributes") }

    it "initializes values properly" do
      section = described_class.new_from_network(config)
      expect(section.layer2).to eq(true)
      expect(section.chanids).to eq("0.0.0700:0.0.0701:0.0.0702")
      expect(section.type).to eq("qeth")
    end

    it "sets the parent section" do
      section = described_class.new_from_network(config, parent)
      expect(section.parent).to eq(parent)
    end
  end

  describe ".new_from_hashes" do
    let(:hash) do
      {
        "type"     => "ctc",
        "chanids"  => "0.0.0800:0.0.0801",
        "protocol" => "1"
      }
    end

    it "loads properly type, chanids and boot protocol" do
      section = described_class.new_from_hashes(hash)
      expect(section.type).to eq "ctc"
      expect(section.chanids).to eq("0.0.0800:0.0.0801")
      expect(section.protocol).to eq "1"
    end

    context "using the old syntax for chanids" do
      let(:hash) do
        {
          "type"     => "ctc",
          "chanids"  => "0.0.0800 0.0.0801",
          "protocol" => "1"
        }
      end

      it "loads properly the chanids" do
        section = described_class.new_from_hashes(hash)
        expect(section.chanids).to eq("0.0.0800:0.0.0801")
      end
    end
  end
end
