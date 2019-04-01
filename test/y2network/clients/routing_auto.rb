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
require "y2network/clients/routing_auto"

describe Y2Network::Clients::RoutingAuto do
  let(:routes) do
    [
      {
        "destination" => "default",
        "gateway"     => "192.168.1.1",
        "netmask"     => "255.255.255.0",
        "device"      => "-"
      },
      {
        "destination" => "172.26.0/24",
        "device"      => "eth0"
      }
    ]
  end
  let(:routing_profile) do
    {
      "routing" => {
        "ipv4_forward" => true,
        "ipv6_forward" => false,
        "routes"       => routes
      }
    }
  end

  describe "#import" do
    it "imports the profile routing configuration" do
      subject.import(routing_profile["routing"])
      config = Yast::Lan.yast_config
      expect(config.routing.forward_ipv4).to eq(true)
      expect(config.routing.forward_ipv6).to eq(false)
      expect(config.routing.routes.size).to eq(2)
    end
  end

  describe "#export" do
  end

  xdescribe "#summary" do
    it "shows the current routing configuration" do
    end
  end

  xdescribe "#change" do
    it "runs the routing main dialog" do
    end
  end
end
