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
require "y2network/presenters/route_profile"
require "y2network/route"

describe Y2Network::Presenters::RouteProfile do
  subject(:presenter) { described_class.new(route) }

  let(:route) do
    Y2Network::Route.new(
      to: to, interface: interface, gateway: gateway, source: source, options: options
    )
  end
  let(:to) { IPAddr.new("192.168.122.0/24") }
  let(:interface) { double("interface", name: "eth0") }
  let(:gateway) { IPAddr.new("192.168.122.1") }
  let(:source) { IPAddr.new("192.168.122.122") }
  let(:options) { "some-option" }

  describe "#to_profile" do
    it "returns a hash containing the information for the profile" do
      expect(presenter.to_profile).to eq(
        "destination" => "192.168.122.0/24",
        "device"      => "eth0",
        "gateway"     => "192.168.122.1",
        "source"      => "192.168.122.122",
        "extrapara"   => "some-option"
      )
    end

    context "when it is the default route" do
      let(:to) { :default }

      it "exports the destination as 'default'" do
        expect(presenter.to_profile).to include("destination" => "default")
      end
    end

    context "when there is no gateway" do
      let(:gateway) { nil }

      it "exports the destination as '-'" do
        expect(presenter.to_profile).to include("gateway" => "-")
      end
    end

    context "when there is no associated interface" do
      let(:interface) { :any }

      it "exports the destination as '-'" do
        expect(presenter.to_profile).to include("device" => "-")
      end
    end

    context "when there is no source" do
      let(:source) { nil }

      it "does not export any value as source" do
        expect(presenter.to_profile["source"]).to be_nil
      end
    end
  end
end
