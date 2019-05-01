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
require "y2network/autoinst_profile/routing_section"
require "y2network/config_builder/autoinst_routing"
require "y2network/interface"

describe Y2Network::ConfigBuilder::AutoinstRouting do
  let(:subject) { described_class.new(routing_section) }
  let(:routing_section) do
    Y2Network::AutoinstProfile::RoutingSection.new_from_hashes(routing_profile)
  end

  let(:forwarding_profile) { { "ip_forward" => true } }
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
      },
      {
        "destination" => "192.168.0.0",
        "gateway"     => "192.168.0.34",
        "netmask"     => "255.255.255.0",
        "device"      => "em1"
      }
    ]
  end

  let(:routing_profile) do
    {
      "ipv4_forward" => true,
      "ipv6_forward" => false,
      "routes"       => routes
    }
  end

  describe "#config" do
    it "builds a new Y2Network::Routing config from the profile" do
      expect(subject.config).to be_a Y2Network::Routing
      expect(subject.config.forward_ipv4).to eq(true)
      expect(subject.config.forward_ipv6).to eq(false)
      expect(subject.config.routes.size).to eq(3)
    end

    context "when building routes defined in the profile" do
      context "and a route uses a 'default' destination" do
        it "creates a new default route" do
          default = subject.config.routes.find(&:default?)
          expect(default.default?).to eq(true)
        end
      end

      context "and the route defines a device" do
        it "initializes the route Y2Network::Interface correctly" do
          em1 = subject.config.routes.find { |r| r.interface == Y2Network::Interface.new("em1") }
          expect(em1.interface).to be_a(Y2Network::Interface)
          expect(em1.interface.name).to eq("em1")
        end
      end
    end

    context "when ip forwarding is not set" do
      let(:routing_profile) { { "routing" => { "routes" => routes } } }

      it "disables ipv4_forward" do
        expect(subject.config.forward_ipv4).to eq(false)
      end

      it "disables ipv6_forward" do
        expect(subject.config.forward_ipv6).to eq(false)
      end
    end

    context "when ip forwarding is set" do
      let(:routing_profile) { { "ip_forward" => true, "routing" => { "routes" => routes } } }

      it "enables ipv4_forward" do
        expect(subject.config.forward_ipv4).to eq(true)
      end

      it "disables ipv6_forward" do
        expect(subject.config.forward_ipv6).to eq(true)
      end
    end
  end
end
