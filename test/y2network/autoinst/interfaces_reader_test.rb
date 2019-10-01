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

require_relative "../../test_helper"
require "y2network/autoinst_profile/interfaces_section"
require "y2network/autoinst/interfaces_reader"
require "y2network/interface"

describe Y2Network::Autoinst::InterfacesReader do
  let(:subject) { described_class.new(interfaces_section) }
  let(:interfaces_section) do
    Y2Network::AutoinstProfile::InterfacesSection.new_from_hashes(interfaces_profile)
  end

  let(:interfaces_profile) do
    [
      { "startmode" => "auto",
        "bootproto" => "static",
        "device"    => "eth1",
        "name"      => "",
        "ipaddr"    => "192.168.10.10",
        "netmask"   => "255.255.255.0",
        "prefixlen" => "24"
      },
      {
        "bootproto" => "dhcp",
        "name"      => "eth0",
        "startmode" => "auto",
        "aliases"   => {
          "alias0" => {
            "IPADDR"    => "10.100.0.1",
            "PREFIXLEN" => "24",
            "LABEL"     => "test"
          },
          "alias1" => {
            "IPADDR"    => "10.100.0.2",
            "PREFIXLEN" => "24",
            "LABEL"     => "test2"
          }
        }
      }
    ]
  end

  describe "#config" do
    it "builds a new Y2Network::ConnectionConfigsCollection" do
      expect(subject.config).to be_a Y2Network::ConnectionConfigsCollection
      expect(subject.config.size).to eq(2)
    end

    it "assign properly all values in profile" do
      eth0_config = subject.config.by_name("eth0")
      expect(eth0_config.startmode).to eq Y2Network::Startmode.create("auto")
      expect(eth0_config.bootproto).to eq Y2Network::BootProtocol.from_name("dhcp")
      expect(eth0_config.ip_aliases.size).to eq 2
      eth1_config = subject.config.by_name("eth1")
      expect(eth1_config.name).to eq("eth1")
      expect(eth1_config.ip.address.to_s).to eq("192.168.10.10/24")
    end
  end
end
