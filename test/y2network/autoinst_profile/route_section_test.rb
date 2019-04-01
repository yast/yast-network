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
require "y2network/autoinst_profile/route_section"
require "y2network/route"

describe Y2Network::AutoinstProfile::RouteSection do
  subject(:section) { described_class.new }

  describe ".new_from_network" do
    let(:route) do
      Y2Network::Route.new(
        to: to, interface: interface, gateway: gateway, options: options
      )
    end
    let(:to) { IPAddr.new("192.168.122.0/24") }
    let(:interface) { double("interface", name: "eth0") }
    let(:gateway) { IPAddr.new("192.168.122.1") }
    let(:options) { "some-option" }

    it "initializes the destination value" do
      section = described_class.new_from_network(route)
      expect(section.destination).to eq("192.168.122.0")
    end

    context "when it is the default route" do
      let(:to) { :default }

      it "initializes the destination to 'default'" do
        section = described_class.new_from_network(route)
        expect(section.destination).to eq("default")
      end
    end

    it "initializes the device value" do
      section = described_class.new_from_network(route)
      expect(section.device).to eq("eth0")
    end

    context "when the interface is any" do
      let(:interface) { :any }

      it "initializes the device to '-'" do
        section = described_class.new_from_network(route)
        expect(section.device).to eq("-")
      end
    end

    it "initializes the gateway value" do
      section = described_class.new_from_network(route)
      expect(section.gateway).to eq("192.168.122.1")
    end

    context "when the gateway is missing" do
      let(:gateway) { nil }

      it "initializes the gateway to '-'" do
        section = described_class.new_from_network(route)
        expect(section.gateway).to eq("-")
      end
    end

    it "initializes the netmask value" do
      section = described_class.new_from_network(route)
      expect(section.netmask).to eq("255.255.255.0")
    end

    context "when it is the default route" do
      let(:to) { :default }

      it "initializes the netmask to '-'" do
        section = described_class.new_from_network(route)
        expect(section.netmask).to eq("-")
      end
    end

    it "initializes the extrapara value" do
      section = described_class.new_from_network(route)
      expect(section.extrapara).to eq("some-option")
    end

    context "when options are missing" do
      let(:options) { nil }

      it "initializes the options to ''" do
        section = described_class.new_from_network(route)
        expect(section.extrapara).to eq("")
      end
    end
  end

  describe ".new_from_hashes" do
    let(:hash) do
      {
        "destination" => "192.168.122.0",
        "netmask"     => "255.255.255.0",
        "device"      => "eth0",
        "gateway"     => "192.168.122.1",
        "extrapara"   => "foo"
      }
    end

    let(:default_gateway) do
      {
        "destination" => "default",
        "device"      => "eth1",
        "gateway"     => "192.168.1.1"
      }
    end

    it "initializes destination" do
      section = described_class.new_from_hashes(hash)
      expect(section.destination).to eq(hash["destination"])
    end

    it "initializes netmask" do
      section = described_class.new_from_hashes(hash)
      expect(section.netmask).to eq(hash["netmask"])
    end

    it "initializes device" do
      section = described_class.new_from_hashes(hash)
      expect(section.device).to eq(hash["device"])
    end

    it "initializes gateway" do
      section = described_class.new_from_hashes(hash)
      expect(section.gateway).to eq(hash["gateway"])
    end

    it "initializes extrapara" do
      section = described_class.new_from_hashes(hash)
      expect(section.extrapara).to eq(hash["extrapara"])
    end
  end
end
