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
require "y2network/config"
require "y2network/autoinst_profile/networking_section"
require "y2network/autoinst/config_reader"
require "y2network/wicked/interfaces_reader"

describe Y2Network::Autoinst::ConfigReader do
  let(:subject) { described_class.new(networking_section, system_config) }
  let(:networking_section) do
    Y2Network::AutoinstProfile::NetworkingSection.new_from_hashes(profile)
  end
  let(:system_config) { Y2Network::Config.new(source: :testing) }

  let(:eth0) { { "device" => "eth0", "bootproto" => "dhcp", "startmode" => "auto" } }
  let(:interfaces) { [eth0] }

  let(:dns) { { "hostname" => "host", "dhcp_hostname" => true, "write_hostname" => true } }
  let(:routes) do
    [
      {
        "destination" => "default",
        "gateway"     => "192.168.1.1",
        "netmask"     => "255.255.255.0",
        "device"      => "-"
      },
      {
        "destination" => "172.26.0.0/24",
        "device"      => "eth0"
      }
    ]
  end

  let(:profile) do
    {
      "interfaces" => interfaces,
      "routing"    => {
        "ipv4_forward" => true,
        "ipv6_forward" => false,
        "routes"       => routes
      },
      "dns"        => dns
    }
  end

  describe "#read" do
    let(:first_stage) { true }

    before do
      allow(Yast::Stage).to receive(:initial).and_return(first_stage)
    end

    it "builds a new Y2Network::Config from a Y2Networking::Section" do
      config = subject.read.config
      expect(config).to be_a Y2Network::Config
      expect(config.routing).to be_a Y2Network::Routing
      expect(config.dns).to be_a Y2Network::DNS
      expect(config.hostname.dhcp_hostname).to eq(:any)
      expect(config.hostname.installer).to eq("host")
      expect(config.backend.id).to eq(:wicked)
    end

    context "when running during the first stage of the installation" do
      it "selects :wicked as the backend to be used" do
        config = subject.read.config
        expect(config.backend.id).to eq(:wicked)
      end
    end

    context "when not running in the first stage of the installation" do
      let(:first_stage) { false }

      context "and it is selected to use a particular network backend" do
        before do
          profile["backend"] = "none"
        end

        it "selects the given backend as the one to be used" do
          config = subject.read.config
          expect(config.backend.id).to eq(:none)
        end
      end

      context "and it is not backend selected but it sets the network to be managed" do
        before do
          profile["managed"] = true
        end

        it "selects :network_manager as the backend to be used" do
          config = subject.read.config
          expect(config.backend.id).to eq(:network_manager)
        end
      end
    end
  end
end
