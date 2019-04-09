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

require "y2network/serializer/route_sysconfig"
require "y2network/interface"

describe Y2Network::Serializer::RouteSysconfig do
  let(:interface) { Y2Network::Interface.new("em1") }
  let(:gateway) { IPAddr.new("192.168.1.1") }
  let(:destination) { IPAddr.new("192.168.1.0/24") }
  let(:default_route) do
    Y2Network::Route.new(
      to:        :default,
      gateway:   gateway,
      interface: interface,
      options:   "table one"
    )
  end

  let(:network_route) do
    Y2Network::Route.new(
      to:        destination,
      gateway:   gateway,
      interface: interface,
      options:   "table one"
    )
  end

  describe "#to_hash" do
    it "exports the given route to a hash" do
      expect(subject.to_hash(default_route)).to be_a(Hash)
    end

    context "when it is a default route" do
      it "exports 'destination' as 'default'" do
        expect(subject.to_hash(default_route)["destination"]).to eq("default")
      end
    end

    context "when the route is not a default one" do
      it "exports 'destination' with the prefix" do
        expect(subject.to_hash(network_route)["destination"]).to eq("192.168.1.0/24")
      end

      it "exports 'netmask' as '-'" do
        expect(subject.to_hash(network_route)["netmask"]).to eq("-")
      end
    end

    context "when the route does not have a gateway" do
      let(:gateway) { nil }

      it "is exported as '-'" do
        expect(subject.to_hash(default_route)["gateway"]).to eq("-")
      end
    end
  end

  describe "#from_hash" do
    let(:route_hash) do
      {
        "destination" => "default",
        "gateway"     => "192.168.1.1",
        "netmask"     => "-",
        "device"      => "em1",
        "extrapara"   => "table one"
      }
    end

    it "instantiates a Y2Network::Route from the given hash" do
      expect(subject.from_hash(route_hash)).to eq(default_route)
    end
  end
end
